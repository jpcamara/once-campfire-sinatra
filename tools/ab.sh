#!/usr/bin/env bash
# ab.sh IMAGE_A IMAGE_B [REPS] [ROUTES] -> c=16 req/s per route, medians over REPS alternating reps.
# Each image run (fresh seed, warmup, 8 s per route) takes the bench lock on its own.
set -euo pipefail
a=$1 b=$2 reps=${3:-3} routes=${4:-room messages sidebar search post}
cd /opt/campfire-perf/once-campfire-rust
res=$(mktemp)
run() {
  local image=$1 rep=$2
  flock /tmp/campfire-bench.lock bash -c '
    image=$1 rep=$2 res=$3; shift 3
    LOG_LEVEL=warn WEB_CONCURRENCY=4 bench/probe start "$image" >/dev/null
    rm -f bench/.work/probe/cookie
    for r in "$@"; do bench/probe load $r 4 2 >/dev/null; done
    for r in "$@"; do
      rps=$(bench/probe load $r 16 8 | python3 -c "import json,sys; d=json.load(sys.stdin); assert d[\"errors\"]==0 and list(d[\"statuses\"])==[\"200\"], d[\"statuses\"]; print(d[\"rps\"])")
      echo "$image $rep $r $rps" >> "$res"
    done
    bench/probe stop' _ "$image" "$rep" "$res" $routes
}
for rep in $(seq 1 "$reps"); do
  if [ $((rep % 2)) = 1 ]; then run "$a" "$rep"; run "$b" "$rep"; else run "$b" "$rep"; run "$a" "$rep"; fi
done
python3 - "$res" "$a" "$b" $routes <<'PY'
import sys, statistics as st
from collections import defaultdict
rows = defaultdict(list)
for line in open(sys.argv[1]):
    image, rep, route, rps = line.split(); rows[(image, route)].append(float(rps))
a, b, routes = sys.argv[2], sys.argv[3], sys.argv[4:]
print(f"{'route':10} {a.split(':')[-1]:>22} {b.split(':')[-1]:>22}  change")
for r in routes:
    ma, mb = st.median(rows[(a, r)]), st.median(rows[(b, r)])
    fmt = lambda v: f"{st.median(v):6.0f} [{min(v):.0f}-{max(v):.0f}]"
    print(f"{r:10} {fmt(rows[(a, r)]):>22} {fmt(rows[(b, r)]):>22}  {100*(mb/ma-1):+5.1f}%")
PY
rm -f "$res"
