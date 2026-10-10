#!/usr/bin/env bash
# On the box, under the bench lock: pagecache-check.sh APP IMAGE -> checks the finished-page cache
# (PageCache) of APP (sinatra, rage or roda) from the outside. Each scenario runs twice, with
# CAMPFIRE_RESPONSE_CACHE_MB=64 and =0, on fresh seed copies, and every status and body must match
# between the two. Scenarios: repeated reads (gzip and identity), a foreign write to a message body
# and to a creator's name, a revoked membership, a banned user, a deleted session. Then a check-mode
# run (CAMPFIRE_CHECK_CACHES=1) with reads around posts from all 4 processes, counting mismatches.
set -uo pipefail
app=$1 image=$2
cd /opt/campfire-perf/once-campfire-rust
label() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' parity/.seed/default/labels.json "$1"; }
case "$app" in sinatra) port=4490 ;; rage) port=4590 ;; roda) port=4790 ;; *) echo "unknown app $app" >&2; exit 2 ;; esac
probe=/opt/campfire-perf/apps/$app/script/box-probe
work=/opt/campfire-perf/.work-$app/probe
B=http://127.0.0.1:$port
W=$(label rooms.watercooler) HQ=$(label rooms.hq)
out=$(mktemp -d)

sql() { python3 - "$work/db/production.sqlite3" "$@" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1], timeout=10)
db.execute(sys.argv[2], sys.argv[3:])
db.commit()
PY
}
fetch() { # fetch NAME PATH [curl args...] -> "status sha" line in the run's log
  local name=$1 path=$2; shift 2
  local tmp; tmp=$(mktemp)
  local code; code=$(curl -s -o "$tmp" -w "%{http_code}" -H "Cookie: $cookie" "$@" "$B$path")
  echo "$name $code $(sed -E 's/[0-9a-f]{32,}//g' "$tmp" | sha1sum | cut -c1-12) $(grep -c 'watercooler-cache-probe\|Cache Probe Name' "$tmp")" >> "$log"
  rm -f "$tmp"
}

run() { # run MB -> scenarios against a fresh container with CAMPFIRE_RESPONSE_CACHE_MB=MB
  local mb=$1
  log=$out/run-$mb.txt; : > "$log"
  EXTRA_ENV="-e CAMPFIRE_RESPONSE_CACHE_MB=$mb" WEB_CONCURRENCY=4 $probe start "$image" >/dev/null || { echo "start failed"; return 1; }
  rm -f "$work/cookie"; cookie=$($probe login)
  local david; david=$(python3 -c "import sqlite3,sys;print(sqlite3.connect(sys.argv[1]).execute('SELECT id FROM users WHERE email_address = ?', (sys.argv[2],)).fetchone()[0])" "$work/db/production.sqlite3" "$(label emails.david)")
  for i in 1 2 3 4; do  # warm every process
    fetch "room-gzip-$i" "/rooms/$W" --compressed
    fetch "room-plain-$i" "/rooms/$W"
    fetch "sidebar-$i" /users/me/sidebar --compressed
    fetch "search-$i" "/searches?q=coffee" --compressed
    fetch "messages-$i" "/rooms/$W/messages?before=$(label messages.busy_060)" --compressed
  done
  local msg; msg=$(python3 -c "import sqlite3;print(sqlite3.connect('$work/db/production.sqlite3').execute('SELECT id FROM messages WHERE room_id = ? ORDER BY created_at DESC LIMIT 1', ($W,)).fetchone()[0])")
  # Foreign writes touch updated_at, as any app write does: message fragments are keyed by it (as in stock Rails).
  sql "UPDATE action_text_rich_texts SET body = '<div>watercooler-cache-probe</div>' WHERE record_type = 'Message' AND record_id = ?" "$msg"
  sql "UPDATE messages SET updated_at = '2030-01-01 00:00:00.000000' WHERE id = ?" "$msg"
  for i in 1 2 3 4; do fetch "after-body-$i" "/rooms/$W" --compressed; done
  local creator; creator=$(python3 -c "import sqlite3;print(sqlite3.connect('$work/db/production.sqlite3').execute('SELECT creator_id FROM messages WHERE id = ?', ($msg,)).fetchone()[0])")
  sql "UPDATE users SET name = 'Cache Probe Name', updated_at = '2030-01-01 00:00:00.000000' WHERE id = ?" "$creator"
  sql "UPDATE messages SET updated_at = '2030-01-01 00:00:01.000000' WHERE id = ?" "$msg"
  for i in 1 2 3 4; do fetch "after-name-$i" "/rooms/$W" --compressed; done
  for i in 1 2 3 4; do fetch "hq-warm-$i" "/rooms/$HQ" --compressed; done
  sql "DELETE FROM memberships WHERE room_id = ? AND user_id = ?" "$W" "$david"
  for i in 1 2 3 4; do fetch "revoked-room-$i" "/rooms/$W" --compressed; fetch "revoked-messages-$i" "/rooms/$W/messages" --compressed; done
  sql "UPDATE users SET status = 2 WHERE id = ?" "$david"
  for i in 1 2 3 4; do fetch "banned-hq-$i" "/rooms/$HQ" --compressed; fetch "banned-sidebar-$i" /users/me/sidebar --compressed; done
  sql "UPDATE users SET status = 0 WHERE id = ?" "$david"
  for i in 1 2 3 4; do fetch "unbanned-hq-$i" "/rooms/$HQ" --compressed; done
  sql "DELETE FROM sessions WHERE user_id = ?" "$david"
  for i in 1 2 3 4; do fetch "nosession-hq-$i" "/rooms/$HQ" --compressed; fetch "nosession-sidebar-$i" /users/me/sidebar --compressed; done
  $probe stop
}

run 64; run 0
echo "== scenarios, cache 64 vs 0"
cut -d" " -f1,2 "$out/run-64.txt" > "$out/s64"; cut -d" " -f1,2 "$out/run-0.txt" > "$out/s0"
if diff -q "$out/s64" "$out/s0" >/dev/null; then echo "PASS statuses identical with the cache on and off ($(wc -l < "$out/s64") requests)"; else echo "FAIL statuses differ:"; diff "$out/s64" "$out/s0" | head; fi
grep -E "^(room|sidebar|search|messages)" "$out/run-64.txt" | cut -d" " -f1-3 > "$out/w64"; grep -E "^(room|sidebar|search|messages)" "$out/run-0.txt" | cut -d" " -f1-3 > "$out/w0"
if diff -q "$out/w64" "$out/w0" >/dev/null; then echo "PASS pages before any write byte-identical with the cache on and off"; else echo "FAIL pages differ before writes:"; diff "$out/w64" "$out/w0" | head; fi
stale=$(grep -E "^after-(body|name)" "$out/run-64.txt" | awk '$4 == 0' | wc -l)
[ "$stale" = 0 ] && echo "PASS every read after a foreign write shows it (8 of 8)" || echo "FAIL $stale reads after a foreign write didn't show it"
grep -E "^(revoked-room-1|revoked-messages-1|banned-hq-1|banned-sidebar-1|nosession-hq-1|nosession-sidebar-1) " "$out/run-64.txt" | cut -d" " -f1,2

echo "== check mode (CAMPFIRE_CHECK_CACHES=1)"
EXTRA_ENV="-e CAMPFIRE_CHECK_CACHES=1" WEB_CONCURRENCY=4 $probe start "$image" >/dev/null
rm -f "$work/cookie"; cookie=$($probe login)
paths=("/rooms/$W" "/rooms/$HQ" "/rooms/$W/messages?before=$(label messages.busy_060)" /users/me/sidebar "/searches?q=coffee" "/searches")
for round in 1 2 3; do
  for p in "${paths[@]}"; do for _ in 1 2 3 4 5 6; do curl -s -o /dev/null --compressed -H "Cookie: $cookie" "$B$p"; curl -s -o /dev/null -H "Cookie: $cookie" "$B$p"; done; done
  curl -s -o /dev/null -H "Cookie: $cookie" -H "Sec-Fetch-Site: same-origin" -H "Accept: text/vnd.turbo-stream.html" \
    --data-urlencode "message[body]=check round $round coffee" "$B/rooms/$HQ/messages"
  sql "UPDATE users SET name = 'Foreign $round' WHERE id = (SELECT creator_id FROM messages WHERE room_id = ? ORDER BY created_at DESC LIMIT 1)" "$W"
done
for r in room sidebar search messages; do $probe load $r 16 3 >/dev/null; done
echo "mismatches: $(docker logs $app-probe 2>&1 | grep -c 'CACHE MISMATCH' || true)"
docker logs $app-probe 2>&1 | grep 'CACHE MISMATCH' | head -5 || true
$probe stop
rm -rf "$out"
