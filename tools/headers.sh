#!/usr/bin/env bash
# headers.sh IMAGE... -> response headers for the bench routes (gzip accepted), per image, for comparison.
# Drops headers that differ between runs (date, request id, runtime, cookies' values).
set -euo pipefail
cd /opt/campfire-perf/once-campfire-rust
label() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' parity/.seed/default/labels.json "$1"; }
W=$(label rooms.watercooler)
for image in "$@"; do
  LOG_LEVEL=warn bench/probe start "$image" >/dev/null
  rm -f bench/.work/probe/cookie; c=$(bench/probe login)
  for p in "/rooms/$W" "/rooms/$W/messages?before=$(label messages.busy_060)" /users/me/sidebar "/searches?q=coffee" /up; do
    echo "== $image $p"
    curl -s -D - -o /dev/null -H "Cookie: $c" -H "Accept-Encoding: gzip" "http://127.0.0.1:4390$p" \
      | tr -d '\r' | grep -viE '^(date|x-request-id|x-runtime|transfer-encoding|content-length):' | sed -E 's/(set-cookie: [^=]+=).*/\1.../I; s/(etag: ).*/\1.../I' | sort
    echo "-- again (If-None-Match)"
    etag=$(curl -s -D - -o /dev/null -H "Cookie: $c" -H "Accept-Encoding: gzip" "http://127.0.0.1:4390$p" | tr -d '\r' | awk -F': ' 'tolower($1)=="etag"{print $2}')
    curl -s -o /dev/null -w "%{http_code}\n" -H "Cookie: $c" -H "If-None-Match: $etag" -H "Accept-Encoding: gzip" "http://127.0.0.1:4390$p"
  done
  bench/probe stop
done
