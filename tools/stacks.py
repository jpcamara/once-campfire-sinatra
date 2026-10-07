#!/usr/bin/env python3
"""stacks.py FILE.collapsed [N] [FILTER] -- self and inclusive time by frame, idle frames removed.

Frames are "function - path:line" as rbspy writes them. FILTER keeps only stacks containing it.
"""
import re, sys
from collections import Counter

IDLE = re.compile(r"IO\.select|io_wait|IO::Event|Selector#select|Kernel#sleep|ConditionVariable#wait|"
                  r"Thread::Queue#pop|Queue#pop|Mutex#sleep|wait_readable|Process\.wait|IO#wait|"
                  r"Thread#join|Async::Scheduler#run_once|Scheduler#block|Monitor#wait|"
                  r"Fiber#transfer|Async::Notification#wait|Redis.*read|Socket#accept|accept_nonblock|"
                  r"IO#read\b|IO#readpartial|IO#gets|<idle>")

def frame_name(f):
    f = re.sub(r" \[c function\]", "", f)
    return re.sub(r" - /usr/local/bundle/ruby/3\.4\.0/(bundler/)?gems/", " - ", f)

path, n = sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 40
flt = sys.argv[3] if len(sys.argv) > 3 else None
selfc, incl, total, idle = Counter(), Counter(), 0, 0
for line in open(path):
    stack, _, count = line.rstrip().rpartition(" ")
    count = int(count)
    if flt and flt not in stack:
        continue
    frames = stack.split(";")
    if IDLE.search(frames[-1]):
        idle += count
        continue
    total += count
    selfc[frame_name(frames[-1])] += count
    for f in set(frame_name(f) for f in frames):
        incl[f] += count
print(f"active samples {total}, idle {idle} ({100*total/max(1,total+idle):.0f}% active)")
print("--- self")
for f, c in selfc.most_common(n):
    print(f"{100*c/total:5.1f}%  {f[:170]}")
print("--- inclusive")
for f, c in incl.most_common(n * 2):
    print(f"{100*c/total:5.1f}%  {f[:170]}")
