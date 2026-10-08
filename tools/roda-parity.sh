#!/usr/bin/env bash
# Playwright parity for campfire-roda-candidate:TAG on every seed: the default inventory in six batches,
# then each other seed whole. Each batch holds the bench lock. Ports 4411/4412 (+1000s isolated).
tag=$1
P=/opt/campfire-perf/tools/parity-app.sh
img=campfire-roda-candidate:$tag
$P roda-$tag "$img" 4411,4412 default r1 \
  "b1-auth-errors=auth/**,errors/**,welcome/**,welcome" "b2-rooms=rooms/**" "b3-messages=messages/**" \
  "b4-interactions=interactions/**" "b5-account-users=account/**,users/**" \
  "b6-rest=search/**,realtime/**,bot_api/**,autocompletable/**,pwa/**"
for seed in crowd custom_styles first_run restricted; do $P roda-$tag "$img" 4411,4412 $seed $seed "all=**"; done
echo all-seeds-done > /opt/campfire-perf/once-campfire-rust/parity/out/roda-$tag-ALL-DONE
