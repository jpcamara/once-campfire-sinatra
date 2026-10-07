#!/usr/bin/env bash
# pagediff.sh IMAGE_A IMAGE_B -> diffs of GET pages and a message post between two app images.
# Each image runs on a fresh seed copy in the probe container (one at a time: both would want
# Redis on 6390). CSRF elements (the csrf meta tags, authenticity_token fields) are removed from both
# sides: the Rust port's documented divergence. Ids and times that differ between runs are masked.
# Run it under flock /tmp/campfire-bench.lock.
set -euo pipefail
cd /opt/campfire-perf/once-campfire-rust
out=/opt/campfire-perf/pagediff; rm -rf "$out"; mkdir -p "$out"
label() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' parity/.seed/default/labels.json "$1"; }
W=$(label rooms.watercooler) HQ=$(label rooms.hq)
paths=(
  "/rooms/$W" "/rooms/$HQ" "/rooms/$(label rooms.pets)" "/rooms/$(label rooms.designers)"
  "/rooms/$(label rooms.david_and_jason)" "/rooms/$(label rooms.group_direct)" "/rooms/$(label rooms.quiet)"
  "/rooms/$(label rooms.david_and_kevin)" "/rooms/$(label rooms.archive)"
  "/rooms/$W/messages?before=$(label messages.busy_060)" "/rooms/$W/messages?after=$(label messages.busy_010)"
  "/rooms/$W/messages?before=$(label messages.busy_020)" "/rooms/$W/@$(label messages.busy_030)"
  "/users/me/sidebar" "/searches?q=coffee" "/searches?q=pizza" "/searches" "/account/edit"
  "/users/$(label users.jason)" "/users/me/profile" "/rooms/$W/involvement"
  "/rooms/opens/new" "/rooms/closeds/new" "/rooms/directs/new" "/webmanifest.json" "/"
)
for image in "$1" "$2"; do
  dir=$out/$(echo "$image" | tr ':/' '__'); mkdir -p "$dir"
  LOG_LEVEL=warn bench/probe start "$image" >/dev/null
  rm -f bench/.work/probe/cookie
  cookie=$(bench/probe login); csrf=$(cat bench/.work/probe/csrf)
  i=0
  for p in "${paths[@]}"; do
    i=$((i + 1))
    curl -s -o "$dir/$i.body" -w "%{http_code} %{content_type} $p\n" -H "Cookie: $cookie" -H "Accept: text/html" "http://127.0.0.1:4390$p" >> "$dir/index"
  done
  for a in /robots.txt /404.html $(grep -o '/assets/[^"]*\.\(css\|js\|svg\)' "$dir/1.body" | sort -u | head -3); do
    i=$((i + 1))
    curl -s -o "$dir/$i.body" -w "%{http_code} %{content_type} $a\n" --compressed "http://127.0.0.1:4390$a" >> "$dir/index"
  done
  curl -s -o "$dir/post.body" -w "%{http_code} %{content_type} POST\n" -H "Cookie: $cookie" \
    -H "Accept: text/vnd.turbo-stream.html, text/html" -H "X-CSRF-Token: $csrf" -H "Sec-Fetch-Site: same-origin" \
    --data-urlencode "message[body]=<div>pagediff hello</div>" --data-urlencode "message[client_message_id]=pagediff-1" \
    "http://127.0.0.1:4390/rooms/$HQ/messages" >> "$dir/index"
  # Again, now from cached fragments, with the posted message, gzipped (decoded by curl).
  for p in "${paths[@]}"; do
    i=$((i + 1))
    curl -s --compressed -o "$dir/$i.body" -w "%{http_code} %{content_type} $p\n" -H "Cookie: $cookie" -H "Accept: text/html" "http://127.0.0.1:4390$p" >> "$dir/index"
  done
  bench/probe stop
  for f in "$dir"/*.body; do
    perl -0pi -e 's/\n *<meta name="csrf-param" content="authenticity_token" \/>\n<meta name="csrf-token" content="[^"]*" \/>//g; s/<input type="hidden" name="authenticity_token" value="[^"]*"(?: autocomplete="off")? \/>//g' "$f"
    sed -i -E 's/(id="message_)[0-9]+/\1ID/g; s/(data-message-id=")[0-9]+/\1ID/g; s/(data-(message-timestamp|message-updated-at|sort-value|refresh-room-loaded-at-value)=")[0-9]+/\1T/g; s/(datetime=")[^"]+/\1T/g; s#(/messages/|@)[0-9]{6,}#\1ID#g; s#(session/transfers/)[A-Za-z0-9_=-]+#\1MASK#g; s#(/qr_code/)[A-Za-z0-9_=-]+#\1MASK#g; s#(models/file_uploader-)[0-9a-f]+#\1DIGEST#g' "$f"
  done
done
a=$out/$(echo "$1" | tr ':/' '__') b=$out/$(echo "$2" | tr ':/' '__')
if diff -q "$a/index" "$b/index" >/dev/null && diff -rq "$a" "$b" >/dev/null; then
  echo "IDENTICAL: $(wc -l < "$a/index") responses, $(cat "$a"/*.body | wc -c) bytes"
else
  diff "$a/index" "$b/index" || true
  for f in "$a"/*.body; do n=$(basename "$f"); cmp -s "$f" "$b/$n" || { echo "== $n differs: $(sed -n "${n%.body}p" "$a/index" 2>/dev/null)"; diff <(tr '>' '\n' < "$f") <(tr '>' '\n' < "$b/$n") | head -20; }; done
  exit 1
fi
