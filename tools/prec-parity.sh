#!/usr/bin/env bash
# Playwright groups touched by the precedent-audit reverts, for the three apps, each batch under the bench lock.
set -u
cd /opt/campfire-perf/once-campfire-rust
base=/opt/campfire-perf/once-campfire-rust/parity/out/precedent-audit
mkdir -p "$base"
run() { # name image ports only
  out=$base/$1; rm -rf "$out"
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  PARITY_OWNER=prec-$1 PARITY_CANDIDATE_IMAGE=$2 PARITY_CPUS=2 flock /tmp/campfire-bench.lock \
    parity/bin/candidate compare --seed default --ports "$3" --only "$4" --workers 6 --isolated 3 --out "$out" > "$out.log" 2>&1
  echo "exit $?" >> "$out.log"
  python3 /tmp/parity_summary.py "$out/report.json" > "$out.summary" 2>&1
}
groups="auth/**,realtime/**,interactions/composer/**,users/**,messages/**"
run sinatra campfire-sinatra-candidate 4111,4112 "$groups"
run rage campfire-rage-candidate 4211,4212 "$groups"
run rails-opt campfire-railsopt-candidate 4311,4312 "realtime/**,interactions/composer/**"
echo all-done > $base/DONE
