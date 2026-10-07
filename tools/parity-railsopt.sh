#!/usr/bin/env bash
# Playwright parity, reference vs campfire-railsopt-candidate, default seed, the whole inventory in six
# batches (as the Rage and Sinatra runs), each holding the bench lock. Ports 4311/4312 (+1000s isolated).
#   parity-railsopt.sh ROUND
set -u
round=${1:-r1}
cd /opt/campfire-perf/once-campfire-rust
export PARITY_OWNER=rails-opt PARITY_CANDIDATE_IMAGE=campfire-railsopt-candidate PARITY_CPUS=2
base=/opt/campfire-perf/once-campfire-rust/parity/out/rails-opt-$round
mkdir -p "$base"
batch() {
  out=$base/$1; rm -rf "$out"
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  flock /tmp/campfire-bench.lock parity/bin/candidate compare --seed default --ports 4311,4312 --only "$2" --workers 6 --isolated 3 --out "$out" > "$out.log" 2>&1
  echo "exit $?" >> "$out.log"
  python3 /tmp/parity_summary.py "$out/report.json" > "$out.summary" 2>&1
}
batch b1-auth-errors "auth/**,errors/**,welcome/**,welcome"
batch b2-rooms "rooms/**"
batch b3-messages "messages/**"
batch b4-interactions "interactions/**"
batch b5-account-users "account/**,users/**"
batch b6-rest "search/**,realtime/**,bot_api/**,autocompletable/**,pwa/**"
echo all-done > $base/DONE
