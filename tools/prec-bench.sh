#!/usr/bin/env bash
# Final numbers after the precedent-audit reverts: three single-rep runs of the 5-app bench (HTTP + cable),
# app order rotated, then the mixed run for the three Ruby apps (three single-rep runs, order rotated).
# Each run takes the bench lock on its own so other work can interleave.
set -u
cd /opt/campfire-perf/once-campfire-rust
out=/opt/campfire-perf/results/precedent-audit
mkdir -p "$out"
export PATH=/home/yrby/rust/bin:$PATH SERVER_CPUS=4-7 LOADGEN_CPUS=0-3 SUITES="http cable"
orders=("reference,rails-opt,sinatra,rage,rust" "rage,rust,reference,rails-opt,sinatra" "sinatra,rage,rust,reference,rails-opt")
for i in 1 2 3; do
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  flock /tmp/campfire-bench.lock bench/run-hetzner --apps "${orders[$((i-1))]}" --reps 1 --out "$out/run-$i" > "$out/run-$i.log" 2>&1
  echo "run $i exit $?" >> "$out/runs.txt"
done
mixed=("sinatra rage rails-opt" "rage rails-opt sinatra" "rails-opt sinatra rage")
for i in 1 2 3; do
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  MIXED_APPS="${mixed[$((i-1))]}" flock /tmp/campfire-bench.lock bash /opt/campfire-perf/tools/mixed.sh "$out/mixed-$i" 1 > "$out/mixed-$i.log" 2>&1
  echo "mixed $i exit $?" >> "$out/runs.txt"
done
echo all-done >> "$out/runs.txt"
