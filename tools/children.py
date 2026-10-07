#!/usr/bin/env python3
"""children.py FILE.collapsed FRAME [DEPTH] [FILTER] -- where time under FRAME goes.

For each stack containing FRAME (the innermost match), groups samples by the next DEPTH frames
below it, skipping Rails plumbing (capture, instance_exec, public_send, ...)."""
import re, sys
from collections import Counter
NOISE = re.compile(r"capture|instance_exec|public_send|block in |block \(|Kernel#tap|Array#each|"
                   r"with_output_buffer|_run_|run_callbacks|instrument|Monitor#synchronize|Kernel#then|"
                   r"OutputBuffer|safe_concat|Kernel#loop|Enumerator")
def short(f):
    f = re.sub(r" \[c function\]", "", f)
    f = re.sub(r" - /usr/local/bundle/ruby/3\.4\.0/(bundler/)?gems/[^/]+/", " @", f)
    return re.sub(r"__+[0-9]+_[0-9]+", "", f)[:100]
path, target = sys.argv[1], sys.argv[2]
depth = int(sys.argv[3]) if len(sys.argv) > 3 else 1
flt = sys.argv[4] if len(sys.argv) > 4 else None
c, total = Counter(), 0
for line in open(path):
    stack, _, n = line.rstrip().rpartition(" "); n = int(n)
    if flt and flt not in stack: continue
    frames = stack.split(";")
    idx = max((i for i, f in enumerate(frames) if target in f), default=None)
    if idx is None: continue
    total += n
    below = [short(f) for f in frames[idx + 1:] if not NOISE.search(f)][:depth]
    c[" > ".join(below) or "(self)"] += n
print(f"{target}: {total} samples")
for k, n in c.most_common(30): print(f"{100*n/total:5.1f}%  {k}")
