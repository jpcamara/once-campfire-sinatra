#!/usr/bin/env bash
# On the box: roda-verify.sh TAG -> fix checks, cache check mode, and the harness's cable and upload
# suites (1 rep) for campfire-roda:TAG, each step under the bench lock, all output in
# /opt/campfire-perf/.work-roda/verify-TAG.txt, ending with DONE.
out=/opt/campfire-perf/.work-roda/verify-$1.txt
{
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  echo "== fixcheck"; flock /tmp/campfire-bench.lock bash /opt/campfire-perf/tools/roda-fixcheck.sh "campfire-roda:$1" 2>&1
  echo "== checkmode"; flock /tmp/campfire-bench.lock bash /opt/campfire-perf/tools/roda-checkmode.sh "$1" 2>&1
  echo "== cable+upload suites"
  cd /opt/campfire-perf/once-campfire-rust
  PORT=4792 PATH=/home/yrby/rust/bin:$PATH RODA_IMAGE="campfire-roda:$1" SUITES="cable upload" CABLE_CLIENTS="100 1000" LOAD_WAIT_SECS=60 \
    flock /tmp/campfire-bench.lock bench/run-hetzner --apps roda --reps 1 --out "/opt/campfire-perf/.work-roda/suites-$1" 2>&1 | grep -E "cable|upload|rror" | tail -8
  echo DONE
} > "$out" 2>&1
