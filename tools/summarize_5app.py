#!/usr/bin/env python3
"""Medians over bench/run-hetzner result JSONs (one or more run dirs), per app.

    summarize_5app.py DIR [DIR ...]

Prints req/s at 16 clients for the five read/write routes and the avatar, cable p50 delivery and
saturated throughput at 1,000 clients, upload median, idle anon memory and cold start.
"""
import glob
import json
import statistics
import sys

ROUTES = ["room_show", "messages_page", "sidebar", "search", "post_message", "avatar"]
runs = {}
for directory in sys.argv[1:]:
    for path in glob.glob(f"{directory}/**/*.json", recursive=True):
        try:
            data = json.load(open(path))
        except (ValueError, OSError):
            continue
        if isinstance(data, dict) and "http" in data and "app" in data:
            runs.setdefault(data["app"], []).append(data)


def median(values):
    values = [v for v in values if v is not None]
    return statistics.median(values) if values else None


def http(run, route):
    for row in run["http"]:
        if row["route"] == route and row["conc"] == 16:
            return row["rps"]
    return None


def cable(run, field):
    for row in run.get("cable") or []:
        if row["clients"] == 1000:
            return row["latency"]["per_client"]["p50_ms"] if field == "p50" else row["throughput"]["delivered_msgs_per_sec"]
    return None


print("app".ljust(10), *(r[:8].rjust(9) for r in ROUTES), "cable_p50", "cable_tp", "upload", "idle_mb", "cold_ms", "reps")
for app, app_runs in sorted(runs.items()):
    errors = sum(row.get("errors", 0) for run in app_runs for row in run["http"])
    print(
        app.ljust(10),
        *(f"{median([http(r, route) for r in app_runs]) or 0:9.0f}" for route in ROUTES),
        f"{median([cable(r, 'p50') for r in app_runs]) or 0:9.1f}",
        f"{median([cable(r, 'tp') for r in app_runs]) or 0:8.0f}",
        f"{median([(r.get('upload') or {}).get('median_total_ms') for r in app_runs]) or 0:6.0f}",
        f"{median([(r.get('memory') or {}).get('idle_anon_mb') for r in app_runs]) or 0:7.0f}",
        f"{median([r.get('cold_start_ms') for r in app_runs]) or 0:7.0f}",
        len(app_runs),
        f"errors={errors}",
    )
