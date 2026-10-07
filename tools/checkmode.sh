#!/usr/bin/env bash
# checkmode.sh IMAGE -> runs IMAGE with CAMPFIRE_CHECK_CACHES=1, reads the cached routes repeatedly
# around posts (from all 4 processes), and prints any "Kept response differs" log lines.
set -euo pipefail
cd /opt/campfire-perf/once-campfire-rust
label() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' parity/.seed/default/labels.json "$1"; }
W=$(label rooms.watercooler) HQ=$(label rooms.hq)
EXTRA_ENV="CAMPFIRE_CHECK_CACHES=1" LOG_LEVEL=warn WEB_CONCURRENCY=4 bench/probe start "$1" >/dev/null
rm -f bench/.work/probe/cookie; c=$(bench/probe login)
paths=("/rooms/$W" "/rooms/$HQ" "/rooms/$W/messages?before=$(label messages.busy_060)" /users/me/sidebar "/searches?q=coffee" "/searches?q=pizza" "/searches")
for round in 1 2 3; do
  for p in "${paths[@]}"; do for _ in 1 2 3 4 5 6; do curl -s -o /dev/null --compressed -H "Cookie: $c" "http://127.0.0.1:4390$p"; done; done
  curl -s -o /dev/null -H "Cookie: $c" -H "Sec-Fetch-Site: same-origin" -H "Accept: text/vnd.turbo-stream.html" \
    --data-urlencode "message[body]=check round $round coffee" "http://127.0.0.1:4390/rooms/$HQ/messages"
done
bench/probe load room 16 3 >/dev/null; bench/probe load sidebar 16 3 >/dev/null; bench/probe load search 16 3 >/dev/null; bench/probe load messages 16 3 >/dev/null
echo "mismatches: $(docker logs campfire-probe 2>&1 | grep -c 'Kept response differs' || true)"
docker logs campfire-probe 2>&1 | grep 'Kept response differs' | head -5 || true
bench/probe stop
