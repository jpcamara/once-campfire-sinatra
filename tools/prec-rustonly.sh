#!/usr/bin/env bash
# CAMPFIRE_CACHING=rust for the three Ruby apps after the precedent-audit reverts: three single-rep HTTP runs, order rotated.
set -u
cd /opt/campfire-perf/once-campfire-rust
out=/opt/campfire-perf/results/precedent-audit-rustonly; mkdir -p "$out"
export PATH=/home/yrby/rust/bin:$PATH SERVER_CPUS=4-7 LOADGEN_CPUS=0-3 SUITES=http VARIANT_ENV="CAMPFIRE_CACHING=rust"
orders=("rails-opt,sinatra,rage" "sinatra,rage,rails-opt" "rage,rails-opt,sinatra")
for i in 1 2 3; do
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  flock /tmp/campfire-bench.lock bench/run-hetzner --apps "${orders[$((i-1))]}" --reps 1 --out "$out/run-$i" > "$out/run-$i.log" 2>&1
  echo "run $i exit $?" >> "$out/runs.txt"
done
echo all-done >> "$out/runs.txt"
