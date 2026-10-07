#!/usr/bin/env bash
# cpuload.sh IMAGE ROUTE -> req/s and the container's CPU use (cores) during an 8 s c=16 load,
# after warming every route as ab.sh does.
set -euo pipefail
image=$1 route=$2
cd /opt/campfire-perf/once-campfire-rust
LOG_LEVEL=warn WEB_CONCURRENCY=${WEB_CONCURRENCY:-4} bench/probe start "$image" >/dev/null
rm -f bench/.work/probe/cookie
for r in room messages sidebar search post; do bench/probe load $r 4 2 >/dev/null; done
cg=/sys/fs/cgroup/system.slice/docker-$(docker inspect -f '{{.Id}}' campfire-probe).scope
u0=$(awk '/usage_usec/{print $2}' $cg/cpu.stat); t0=$(date +%s%N)
rps=$(bench/probe load "$route" 16 8 | python3 -c 'import json,sys; print(round(json.load(sys.stdin)["rps"]))')
u1=$(awk '/usage_usec/{print $2}' $cg/cpu.stat); t1=$(date +%s%N)
echo "$image $route rps=$rps cores=$(python3 -c "print(round(($u1-$u0)/(($t1-$t0)/1000),2))") cpu_ms_per_req=$(python3 -c "print(round(($u1-$u0)/1000/($rps*($t1-$t0)/1e9),2))")"
bench/probe stop
