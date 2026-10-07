#!/usr/bin/env bash
# profile.sh IMAGE ROUTE [SECS] [CONC] -> /opt/campfire-perf/profiles/<image tag>-<route>.collapsed
# Starts the probe container on IMAGE, warms up, then records every Ruby process in it with rbspy
# while the load generator runs ROUTE. Run it under flock /tmp/campfire-bench.lock.
set -euo pipefail
image=$1 route=$2 secs=${3:-15} conc=${4:-16}
tag=${image#*:}
out=/opt/campfire-perf/profiles/$tag-$route
cd /opt/campfire-perf/once-campfire-rust
# PUMA=1 runs the image under Puma (rbspy can't follow Falcon's fibers).
[ -n "${PUMA:-}" ] && export EXTRA_MOUNTS="-v /opt/campfire-perf/tools/start-app-puma:/rails/bin/start-app:ro" && tag=$tag-puma && out=$out-puma
LOG_LEVEL=warn WEB_CONCURRENCY=${WEB_CONCURRENCY:-4} bench/probe start "$image" >/dev/null
rm -f bench/.work/probe/cookie
bench/probe load "$route" 4 3 >/dev/null
# One rbspy per Ruby process: --subprocesses misses forked workers.
pids=$(docker top campfire-probe -eo pid,args | awk 'NR>1 && /ruby|puma|falcon|resque/ && !/thrust|redis/ {print $1}')
bench/probe load "$route" "$conc" $((secs + 2)) > "$out-load.json" &
sleep 1
for pid in $pids; do
  /opt/campfire-perf/tools/rbspy record --pid "$pid" --rate ${RATE:-100} --duration "$secs" \
    --format collapsed --file "$out.$pid.part" --silent 2>/dev/null &
done
wait
cat "$out".*.part > "$out.collapsed"; rm -f "$out".*.part
bench/probe stop
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(sys.argv[2], round(d['rps']), d['statuses'], 'err', d['errors'])" "$out-load.json" "$tag-$route"
