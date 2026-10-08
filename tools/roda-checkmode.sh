#!/usr/bin/env bash
# On the box: roda-checkmode.sh TAG -> campfire-roda:TAG with CAMPFIRE_CHECK_CACHES=1; reads the cached
# routes repeatedly around posts, renames and a read marker (4 processes), then load on each route,
# and counts CACHE MISMATCH lines. Run under the bench lock.
set -euo pipefail
cd /opt/campfire-perf/once-campfire-rust
label() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' parity/.seed/default/labels.json "$1"; }
W=$(label rooms.watercooler) HQ=$(label rooms.hq)
probe=/opt/campfire-perf/apps/roda/script/box-probe
EXTRA_ENV="-e CAMPFIRE_CHECK_CACHES=1" WEB_CONCURRENCY=4 $probe start "campfire-roda:$1" >/dev/null
rm -f /opt/campfire-perf/.work-roda/probe/cookie; c=$($probe login)
B=http://127.0.0.1:4790
paths=("/rooms/$W" "/rooms/$HQ" "/rooms/$W/messages?before=$(label messages.busy_060)" /users/me/sidebar "/searches?q=coffee" "/searches?q=pizza" "/searches")
for round in 1 2 3 4; do
  for p in "${paths[@]}"; do for _ in 1 2 3 4 5 6; do
    curl -s -o /dev/null --compressed -H "Cookie: $c" "$B$p"
    curl -s -o /dev/null -H "Cookie: $c" -H "Turbo-Frame: user_sidebar" "$B$p"
  done; done
  curl -s -o /dev/null -H "Cookie: $c" -H "Sec-Fetch-Site: same-origin" -H "Accept: text/vnd.turbo-stream.html" \
    --data-urlencode "message[body]=check round $round coffee" "$B/rooms/$HQ/messages"
  [ $round = 2 ] && curl -s -o /dev/null -H "Cookie: $c" -H "Sec-Fetch-Site: same-origin" -X POST \
    --data-urlencode "_method=patch" --data-urlencode "user[name]=David Renamed" "$B/users/me/profile"
done
for r in room sidebar search messages; do $probe load $r 16 3 >/dev/null; done
echo "mismatches: $(docker logs roda-probe 2>&1 | grep -c 'CACHE MISMATCH' || true)"
docker logs roda-probe 2>&1 | grep -E 'CACHE MISMATCH|Error|error' | head -5 || true
$probe stop
