#!/usr/bin/env bash
# After the v5 parity run: the 5-app bench (3 reps, rotating order, each rep under the lock), the
# mixed run for roda, then roda with CAMPFIRE_CACHING=rust (HTTP suite, 3 reps).
set -u
until [ -e /opt/campfire-perf/once-campfire-rust/parity/out/roda-v5-ALL-DONE ]; do sleep 30; done
cd /opt/campfire-perf/once-campfire-rust
export PATH=/home/yrby/rust/bin:$PATH SERVER_CPUS=4-7 LOADGEN_CPUS=0-3
R=/opt/campfire-perf/results/roda-5app
mkdir -p $R
orders=("reference,sinatra,rage,roda,rust" "roda,rust,reference,sinatra,rage" "rage,roda,rust,reference,sinatra")
for i in 1 2 3; do
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  flock /tmp/campfire-bench.lock bench/run-hetzner --apps "${orders[$((i-1))]}" --reps 1 --out $R/run-$i > $R/run-$i.log 2>&1
  echo "run $i exit $?" >> $R/runs.txt
done
while [ -e /tmp/box-busy.sq ]; do sleep 30; done
MIXED_APPS=roda flock /tmp/campfire-bench.lock bash /opt/campfire-perf/tools/mixed.sh /opt/campfire-perf/results/roda-mixed 3 > /opt/campfire-perf/results/roda-mixed.log 2>&1
echo "mixed exit $?" >> $R/runs.txt
for i in 1 2 3; do
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  VARIANT_ENV="CAMPFIRE_CACHING=rust" SUITES=http flock /tmp/campfire-bench.lock bench/run-hetzner --apps roda --reps 1 --out /opt/campfire-perf/results/roda-rust-caching/run-$i > /opt/campfire-perf/results/roda-rust-caching-run-$i.log 2>&1
  echo "rust-caching run $i exit $?" >> $R/runs.txt
done
echo ALL-BENCH-DONE >> $R/runs.txt
