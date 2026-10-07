#!/usr/bin/env bash
# On the box: rage-fixcheck.sh IMAGE -> runs IMAGE (rage-probe, :4590) and checks each audit fix from the
# outside: X-Request-Id, /cable origin, forgery rules, bot API forgery, marker injection, the sidebar's
# Link header, blob serving, boost length and private-IP bans. Prints PASS/FAIL lines. Run under the lock.
set -uo pipefail
cd /opt/campfire-perf/once-campfire-rust
label() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' parity/.seed/default/labels.json "$1"; }
W=$(label rooms.watercooler) HQ=$(label rooms.hq) BOT=$(label bot_keys.bender)
probe=/opt/campfire-perf/apps/rage/script/box-probe
WEB_CONCURRENCY=4 $probe start "$1" >/dev/null || exit 1
rm -f /opt/campfire-perf/.work-rage/probe/cookie; c=$($probe login)
B=http://127.0.0.1:4590
fails=0
check() { if [ "$2" = "$3" ]; then echo "PASS $1 ($2)"; else echo "FAIL $1: got '$2', want '$3'"; fails=$((fails + 1)); fi; }
code() { curl -s -o /dev/null -w "%{http_code}" "$@"; }
hdr() { curl -s -D - -o /dev/null "$@" | tr -d '\r'; }

check "x-request-id on a page" "$(hdr -H "Cookie: $c" "$B/rooms/$W" | grep -ci '^x-request-id:')" 1
check "client x-request-id kept, sanitized" "$(hdr -H "Cookie: $c" -H 'X-Request-Id: abc<>def' "$B/up" | grep -i '^x-request-id:' | sed 's/^[^:]*: *//')" abcdef
css=$(ls /opt/campfire-perf/apps/rage/public/assets 2>/dev/null | grep '^_reset-.*[.]css$' | head -1)
css=${css:-$(docker exec rage-probe ls /rails/public/assets | grep '^_reset-.*[.]css$' | head -1)}
check "no x-request-id on an asset" "$(hdr "$B/assets/$css" | grep -ci '^x-request-id:')" 0
check "no x-request-id on /404.html" "$(hdr "$B/404.html" | grep -ci '^x-request-id:')" 0

ws=(-H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" -H "Cookie: $c")
check "cable: foreign origin" "$(code "${ws[@]}" -H "Origin: http://evil.example" "$B/cable")" 404
check "cable: no origin" "$(code "${ws[@]}" "$B/cable")" 404
check "cable: not an upgrade" "$(curl -s -H "Origin: $B" "$B/cable")" "Page not found"
check "cable: same origin" "$(code --max-time 2 "${ws[@]}" -H "Origin: $B" "$B/cable")" 101

post() { code -H "Cookie: $c" -H "Accept: text/vnd.turbo-stream.html" --data-urlencode "message[body]=fixcheck" "$@" "$B/rooms/$HQ/messages"; }
check "forgery: Origin null" "$(post -H 'Origin: null' -H 'Sec-Fetch-Site: same-origin')" 422
check "forgery: foreign Origin" "$(post -H 'Origin: http://evil.example' -H 'Sec-Fetch-Site: same-origin')" 422
check "forgery: Sec-Fetch-Site none" "$(post -H 'Sec-Fetch-Site: none')" 422
check "forgery: cross-site" "$(post -H 'Sec-Fetch-Site: cross-site')" 422
check "forgery: same-site" "$(post -H 'Sec-Fetch-Site: same-site')" 200
check "forgery: no header over plain HTTP" "$(post)" 200
check "forgery: 422 is the public page" "$(curl -s -H "Cookie: $c" -H 'Sec-Fetch-Site: cross-site' --data-urlencode 'message[body]=x' "$B/rooms/$HQ/messages" | grep -c 'didn’t work (422)')" 1
check "forgery: signed-out write goes to sign in" "$(code -H 'Sec-Fetch-Site: cross-site' --data-urlencode 'message[body]=x' "$B/rooms/$HQ/messages")" 302

check "bot API by cookie, cross-site" "$(code -H "Cookie: $c" -H 'Sec-Fetch-Site: cross-site' --data 'hi' "$B/rooms/$W/$BOT/messages")" 422
check "bot API by key, cross-site" "$(code -H 'Sec-Fetch-Site: cross-site' --data 'hi from the key' "$B/rooms/$W/$BOT/messages")" 201

check "marker in a search query" "$(code -H "Cookie: $c" "$B/searches?q=%01999%02")" 200
check "marker in a search query (repeat)" "$(code -H "Cookie: $c" "$B/searches?q=%010%02")" 200

check "sidebar Link header, first" "$(hdr -H "Cookie: $c" "$B/users/me/sidebar" | grep -ci '^link:')" 1
check "sidebar Link header, kept" "$(hdr -H "Cookie: $c" "$B/users/me/sidebar" | grep -ci '^link:')" 1

printf '<script>alert(1)</script>' > /tmp/fixcheck.html
upload=$(curl -s -o /tmp/fixcheck-upload.txt -w "%{http_code}" -H "Cookie: $c" -H 'Sec-Fetch-Site: same-origin' -H 'Accept: text/vnd.turbo-stream.html' \
  -F 'message[attachment]=@/tmp/fixcheck.html;type=text/html' -F 'message[client_message_id]=fixcheck-html' "$B/rooms/$HQ/messages")
check "html upload accepted" "$upload" 200
blob=$( { cat /tmp/fixcheck-upload.txt; curl -s -H "Cookie: $c" "$B/rooms/$HQ"; } | grep -o '/rails/active_storage/blobs/redirect/[^"?]*' | grep -i 'fixcheck' | head -1)
echo "  blob link: ${blob:-none}"
disk=$(hdr -H "Cookie: $c" "$B$blob" | grep -i '^location:' | sed 's/^[^:]*: *//')
served=$(hdr "$disk")
check "html blob type" "$(echo "$served" | grep -i '^content-type:' | sed 's/^[^:]*: *//' | cut -d';' -f1)" application/octet-stream
check "html blob disposition" "$(echo "$served" | grep -i '^content-disposition:' | sed 's/^[^:]*: *//' | cut -d';' -f1)" attachment

long="a boost that is longer than sixteen characters"
got=$(curl -s -H 'Sec-Fetch-Site: same-origin' --data "$long" "$B/rooms/$W/$BOT/messages/$(curl -s "$B/rooms/$W/$BOT/messages" | python3 -c 'import json,sys; print(json.load(sys.stdin)[-1]["id"])')/boosts" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("content"))')
check "boost keeps its full content" "$got" "$long"

# Jason signs in from loopback, so one of his sessions has a private address: Rails' Ban refuses it.
curl -s -o /dev/null -H 'Sec-Fetch-Site: same-origin' --data-urlencode "email_address=$(label emails.jason)" \
  --data-urlencode "password=$(label passwords.all)" "$B/session"
victim=149087659
check "ban with a private-IP session refused" "$(code -H "Cookie: $c" -H 'Sec-Fetch-Site: same-origin' -X POST "$B/users/$victim/ban")" 422
check "the refused ban changed nothing" "$(docker exec -w /rails rage-probe bundle exec ruby -rsqlite3 -e "puts SQLite3::Database.new('/rails/storage/db/production.sqlite3').get_first_value('select status from users where id = $victim')" 2>/dev/null)" 0

echo "failures: $fails"
docker logs rage-probe 2>&1 | grep -E 'Error|CACHE MISMATCH' | grep -v 'Request origin not allowed' | head -5
$probe stop
