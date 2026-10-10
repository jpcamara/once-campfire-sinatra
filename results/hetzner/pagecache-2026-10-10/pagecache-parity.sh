#!/usr/bin/env bash
# On the box: pagecache-parity.sh APP TAG -> Playwright parity for APP's candidate image (tag TAG) on every seed:
# the default inventory in six batches, then each other seed whole. Each batch holds the bench lock.
# Output under parity/out/APP-TAG-<seed>/, summaries in each batch's .summary, DONE marker at the end.
app=$1 tag=$2
case "$app" in sinatra) ports=4111,4112 ;; rage) ports=4211,4212 ;; roda) ports=4411,4412 ;; *) exit 2 ;; esac
P=/opt/campfire-perf/tools/parity-app.sh
img=campfire-$app-candidate:$tag
$P $app-$tag "$img" $ports default default \
  "b1-auth-errors=auth/**,errors/**,welcome/**,welcome" "b2-rooms=rooms/**" "b3-messages=messages/**" \
  "b4-interactions=interactions/**" "b5-account-users=account/**,users/**" \
  "b6-rest=search/**,realtime/**,bot_api/**,autocompletable/**,pwa/**"
for seed in crowd custom_styles first_run restricted; do $P $app-$tag "$img" $ports $seed $seed "all=**"; done
echo done > /opt/campfire-perf/once-campfire-rust/parity/out/$app-$tag-ALL-DONE
