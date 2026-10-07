#!/usr/bin/env python3
"""Post messages at a steady rate (open loop), the same request bench/loadgen's --post-room sends.

  paced_poster.py BASE COOKIE ROOM RATE SECS [WORKERS]

Requests are scheduled at fixed intervals whether or not earlier ones have finished, so a slow server
shows up as latency (from the scheduled time) and a lower achieved rate, not as a lower offered rate.
Prints one JSON object: offered and achieved rate, statuses, errors and latency percentiles in ms.
"""
import http.client, json, queue, sys, threading, time, urllib.parse
from collections import Counter

base, cookie, room, rate, secs = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]), float(sys.argv[5])
workers = int(sys.argv[6]) if len(sys.argv) > 6 else 16
host = urllib.parse.urlparse(base)
jobs, lock = queue.Queue(), threading.Lock()
statuses, latencies, errors = Counter(), [], [0]


def worker():
    conn = None
    while (job := jobs.get()) is not None:
        scheduled, n = job
        body = urllib.parse.urlencode({
            "message[body]": f"mixed write {n}",
            "message[client_message_id]": f"{time.time_ns():x}{n:x}",
            "authenticity_token": "",
        })
        headers = {
            "cookie": cookie,
            "content-type": "application/x-www-form-urlencoded",
            "accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
            "x-csrf-token": "",
            "sec-fetch-site": "same-origin",
            "accept-encoding": "gzip",
        }
        try:
            conn = conn or http.client.HTTPConnection(host.hostname, host.port, timeout=30)
            conn.request("POST", f"/rooms/{room}/messages", body, headers)
            response = conn.getresponse()
            response.read()
            with lock:
                statuses[response.status] += 1
                latencies.append((time.monotonic() - scheduled) * 1000)
            if response.getheader("connection", "").lower() == "close":
                conn.close(); conn = None
        except Exception:
            with lock:
                errors[0] += 1
            if conn:
                conn.close()
            conn = None


threads = [threading.Thread(target=worker, daemon=True) for _ in range(workers)]
for t in threads:
    t.start()

start = time.monotonic()
total = int(rate * secs)
for n in range(total):
    scheduled = start + n / rate
    delay = scheduled - time.monotonic()
    if delay > 0:
        time.sleep(delay)
    jobs.put((scheduled, n))
for _ in threads:
    jobs.put(None)
for t in threads:
    t.join()
elapsed = time.monotonic() - start


def pct(p):
    if not latencies:
        return None
    ordered = sorted(latencies)
    return round(ordered[min(len(ordered) - 1, int(p / 100 * len(ordered)))], 2)


print(json.dumps({
    "offered_rate": rate,
    "achieved_rate": round(sum(statuses.values()) / elapsed, 1),
    "sent": total,
    "statuses": {str(k): v for k, v in statuses.items()},
    "errors": errors[0],
    "latency_ms": {"p50": pct(50), "p90": pct(90), "p99": pct(99), "max": pct(100)},
    "elapsed_s": round(elapsed, 2),
}))
