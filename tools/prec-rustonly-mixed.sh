#!/usr/bin/env bash
# Mixed run with CAMPFIRE_CACHING=rust for the three Ruby apps, after prec-rustonly.sh: three single-rep runs, order rotated.
set -u
until grep -q all-done /opt/campfire-perf/results/precedent-audit-rustonly/runs.txt 2>/dev/null; do sleep 30; done
out=/opt/campfire-perf/results/precedent-audit-rustonly
mixed=("sinatra rage rails-opt" "rage rails-opt sinatra" "rails-opt sinatra rage")
for i in 1 2 3; do
  while [ -e /tmp/box-busy.sq ]; do sleep 30; done
  MIXED_APPS="${mixed[$((i-1))]}" VARIANT_ENV="CAMPFIRE_CACHING=rust" flock /tmp/campfire-bench.lock bash /opt/campfire-perf/tools/mixed.sh "$out/mixed-$i" 1 > "$out/mixed-$i.log" 2>&1
  echo "mixed $i exit $?" >> "$out/mixed.txt"
done
echo all-done >> "$out/mixed.txt"
