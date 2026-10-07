#!/usr/bin/env bash
# cpuby.sh IMAGE ROUTE -> CPU ms per request by process kind (web, jobs, redis, thruster) during an 8 s c=16 load.
set -euo pipefail
image=$1 route=$2
cd /opt/campfire-perf/once-campfire-rust
LOG_LEVEL=warn WEB_CONCURRENCY=4 bench/probe start "$image" >/dev/null
rm -f bench/.work/probe/cookie
for r in room messages sidebar search post; do bench/probe load $r 4 2 >/dev/null; done
snap() { for p in $(docker top campfire-probe -eo pid | tail -n +2); do [ -r /proc/$p/stat ] && echo "$p $(awk '{print $14+$15}' /proc/$p/stat) $(tr '\0' ' ' < /proc/$p/cmdline | cut -c1-60)"; done; }
snap > /tmp/cpu0
rps=$(bench/probe load "$route" 16 8 | python3 -c 'import json,sys; print(json.load(sys.stdin)["rps"])')
snap > /tmp/cpu1
python3 - "$rps" <<'PY'
import sys, os, re
rps = float(sys.argv[1]); hz = os.sysconf("SC_CLK_TCK")
def load(f):
    d = {}
    for line in open(f):
        pid, ticks, cmd = line.rstrip("\n").split(" ", 2); d[pid] = (int(ticks), cmd)
    return d
a, b = load("/tmp/cpu0"), load("/tmp/cpu1")
kinds = {}
for pid, (t1, cmd) in b.items():
    t0 = a.get(pid, (0, cmd))[0]
    k = "thruster" if "thrust" in cmd else "redis" if "redis" in cmd else "jobs" if "resque" in cmd else "web" if ("falcon" in cmd or "puma" in cmd or "ruby" in cmd) else cmd.split()[0] if cmd else "?"
    kinds[k] = kinds.get(k, 0) + (t1 - t0)
total = sum(kinds.values())
print(f"rps {rps:.0f}; CPU ms per request:", ", ".join(f"{k} {1000*v/hz/(rps*8):.2f}" for k, v in sorted(kinds.items(), key=lambda kv: -kv[1])), f"| total {1000*total/hz/(rps*8):.2f}")
PY
bench/probe stop
