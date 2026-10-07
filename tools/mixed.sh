#!/usr/bin/env bash
# Mixed workload: room-page reads at 16 clients (bench/loadgen, as user david, the bench's read route)
# while another member (jason) posts into that same room at a steady rate (tools/paced_poster.py).
# Every (rep, app, rate) gets a fresh container on a fresh copy of the default seed (bench/probe start).
# App order and rate order rotate between reps. Run under the bench lock.
#
#   mixed.sh OUT_DIR [REPS] [READ_SECS]
set -euo pipefail
out=$1 reps=${2:-3} secs=${3:-20}
cd /opt/campfire-perf/once-campfire-rust
mkdir -p "$out"
LOADGEN_CPUS=0-3
LG=target/bench/release/loadgen
labels=parity/.seed/default/labels.json
label() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$labels" "$1"; }
room=$(label rooms.watercooler)
image_for() { case "$1" in sinatra) echo campfire-sinatra:app ;; rage) echo campfire-rage:app ;; rails-opt) echo campfire-reference:rails-opt ;; reference) echo campfire-reference:app ;; esac; }
# Stock Rails keeps its default process count (ceil(nproc * 0.666) = 3); the others run 4, as in bench/run-hetzner.
workers_for() { case "$1" in reference) echo "" ;; *) echo 4 ;; esac; }

apps=(sinatra rage rails-opt reference) rates=(0 20 100)
for rep in $(seq 1 "$reps"); do
  app_shift=$(( (rep - 1) % ${#apps[@]} )) rate_shift=$(( (rep - 1) % ${#rates[@]} ))
  rep_apps=("${apps[@]:app_shift}" "${apps[@]:0:app_shift}")
  rep_rates=("${rates[@]:rate_shift}" "${rates[@]:0:rate_shift}")
  for app in "${rep_apps[@]}"; do
    for rate in "${rep_rates[@]}"; do
      WEB_CONCURRENCY=$(workers_for "$app") LOG_LEVEL=warn bench/probe start "$(image_for "$app")" >/dev/null
      bench/probe login >/dev/null
      poster_cookie=$(taskset -c $LOADGEN_CPUS $LG login --base http://127.0.0.1:4390 --email "$(label emails.jason)" \
        --password "$(label passwords.all)" | python3 -c 'import json,sys; print(json.load(sys.stdin)["cookie"])')
      # Warm both paths: reads, and a few posts by the poster.
      bench/probe load room 4 3 >/dev/null
      taskset -c $LOADGEN_CPUS python3 /opt/campfire-perf/tools/paced_poster.py http://127.0.0.1:4390 "$poster_cookie" "$room" 10 2 >/dev/null
      post_json='null'
      if [ "$rate" -gt 0 ]; then
        taskset -c $LOADGEN_CPUS python3 /opt/campfire-perf/tools/paced_poster.py http://127.0.0.1:4390 "$poster_cookie" "$room" "$rate" $((secs + 6)) > "$out/.post.json" &
        poster=$!
        sleep 3
      fi
      read_json=$(bench/probe load room 16 "$secs")
      if [ "$rate" -gt 0 ]; then wait "$poster"; post_json=$(cat "$out/.post.json"); fi
      python3 -c 'import json,sys; json.dump({"app": sys.argv[2], "rep": int(sys.argv[3]), "rate": int(sys.argv[4]), "read": json.loads(sys.argv[5]), "post": json.loads(sys.argv[6])}, open(sys.argv[1], "w"), indent=1)' \
        "$out/$app-rate$rate-rep$rep.json" "$app" "$rep" "$rate" "$read_json" "$post_json"
      echo "[$(date +%T)] rep $rep $app rate $rate: reads $(python3 -c 'import json,sys; r=json.loads(sys.argv[1]); print(round(r["rps"]), r["statuses"], "err", r["errors"])' "$read_json") posts $(python3 -c 'import json,sys; p=json.loads(sys.argv[1]); print(p and (p["achieved_rate"], p["statuses"], "err", p["errors"], "p50", p["latency_ms"]["p50"]))' "$post_json")"
      bench/probe stop
    done
  done
done
rm -f "$out/.post.json"
echo mixed-done
