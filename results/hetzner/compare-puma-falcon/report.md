```
date: 2026-10-05T19:07:03+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
reference image: campfire-reference:app sha256:0701d9b06ec642db9cdac8efc2854ba0e7f33d404af39d814acbc0d56323f6b0 2026-10-05T17:10:33.410393286+02:00
puma-fixes image: campfire-reference:puma-fixes sha256:a83983eeb714717756c566da45716b1a8e6c4696a588653125f8ad455259a63e 2026-10-05T19:05:00.490817293+02:00
falcon-fixes image: campfire-reference:falcon-fixes sha256:3e3aede4c1165b694b8eb43121ac622537f832f7e3cd32ebc73c88e9e48c89f6 2026-10-05T19:05:58.551592135+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: reference 3. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust adv. |
|---|---|---|
| cold start: docker run → /up 200 (ms) | 3,580 [3,508–3,601] | – |
| idle memory.current (MB) | 303 [303–309] | – |
| idle anon (MB) | 284 [283–289] | – |
| peak memory.current under load (MB) | 912 [890–941] | – |
| peak anon under load (MB) | 813 [812–820] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust adv. |
|---|---|---|
| room_show c=1 req/s | 92.5 [92.5–93.0] | – |
| room_show c=1 p50 ms | 10.5 [10.5–10.6] | – |
| room_show c=1 p99 ms | 12.6 [12.2–12.6] | – |
| room_show c=16 req/s | 223 [219–228] | – |
| room_show c=16 p50 ms | 74.3 [70.7–86.8] | – |
| room_show c=16 p99 ms | 141 [139–150] | – |
| room_show c=64 req/s | 193 [188–199] | – |
| room_show c=64 p50 ms | 341 [300–348] | – |
| room_show c=64 p99 ms | 453 [415–455] | – |
| messages_page c=1 req/s | 163 [162–167] | – |
| messages_page c=1 p50 ms | 6.02 [5.87–6.04] | – |
| messages_page c=1 p99 ms | 7.48 [7.33–7.58] | – |
| messages_page c=16 req/s | 371 [355–392] | – |
| messages_page c=16 p50 ms | 43.6 [18.6–46.5] | – |
| messages_page c=16 p99 ms | 84.4 [84.0–137.5] | – |
| messages_page c=64 req/s | 343 [335–360] | – |
| messages_page c=64 p50 ms | 179 [179–184] | – |
| messages_page c=64 p99 ms | 266 [219–282] | – |
| sidebar c=1 req/s | 204 [201–211] | – |
| sidebar c=1 p50 ms | 4.78 [4.62–4.83] | – |
| sidebar c=1 p99 ms | 6.35 [6.29–6.64] | – |
| sidebar c=16 req/s | 475 [459–490] | – |
| sidebar c=16 p50 ms | 32.6 [32.4–33.8] | – |
| sidebar c=16 p99 ms | 64.7 [64.5–86.1] | – |
| sidebar c=64 req/s | 469 [442–487] | – |
| sidebar c=64 p50 ms | 137 [129–143] | – |
| sidebar c=64 p99 ms | 203 [160–218] | – |
| search c=1 req/s | 161 [160–164] | – |
| search c=1 p50 ms | 6.12 [6.01–6.14] | – |
| search c=1 p99 ms | 7.88 [7.88–7.89] | – |
| search c=16 req/s | 377 [371–383] | – |
| search c=16 p50 ms | 42.3 [41.5–42.5] | – |
| search c=16 p99 ms | 82.7 [78.7–85.6] | – |
| search c=64 req/s | 361 [354–374] | – |
| search c=64 p50 ms | 172 [153–181] | – |
| search c=64 p99 ms | 232 [224–332] | – |
| avatar c=1 req/s | 18,310 [18,242–18,493] | – |
| avatar c=1 p50 ms | 0.05 [0.05–0.05] | – |
| avatar c=1 p99 ms | 0.12 [0.11–0.12] | – |
| avatar c=16 req/s | 62,472 [62,352–62,617] | – |
| avatar c=16 p50 ms | 0.17 [0.17–0.17] | – |
| avatar c=16 p99 ms | 1.29 [1.29–1.29] | – |
| avatar c=64 req/s | 51,157 [50,983–51,992] | – |
| avatar c=64 p50 ms | 0.48 [0.47–0.49] | – |
| avatar c=64 p99 ms | 7.67 [7.43–7.71] | – |
| static_css c=1 req/s | 23,295 [23,153–23,747] | – |
| static_css c=1 p50 ms | 0.04 [0.04–0.04] | – |
| static_css c=1 p99 ms | 0.09 [0.09–0.09] | – |
| static_css c=16 req/s | 85,292 [84,421–86,111] | – |
| static_css c=16 p50 ms | 0.13 [0.13–0.13] | – |
| static_css c=16 p99 ms | 0.95 [0.95–0.98] | – |
| static_css c=64 req/s | 73,282 [72,879–73,283] | – |
| static_css c=64 p50 ms | 0.43 [0.42–0.43] | – |
| static_css c=64 p99 ms | 5.06 [5.05–5.12] | – |
| up c=1 req/s | 1,542 [1,542–1,548] | – |
| up c=1 p50 ms | 0.58 [0.58–0.58] | – |
| up c=1 p99 ms | 1.18 [1.15–1.19] | – |
| up c=16 req/s | 3,502 [3,486–3,521] | – |
| up c=16 p50 ms | 4.44 [4.40–4.47] | – |
| up c=16 p99 ms | 8.76 [8.41–8.87] | – |
| up c=64 req/s | 3,444 [3,431–3,460] | – |
| up c=64 p50 ms | 18.4 [18.4–18.5] | – |
| up c=64 p99 ms | 27.2 [27.0–28.0] | – |
| post_message c=1 req/s | 114 [107–117] | – |
| post_message c=1 p50 ms | 7.92 [7.68–8.13] | – |
| post_message c=1 p99 ms | 28.6 [28.5–32.9] | – |
| post_message c=16 req/s | 199 [190–202] | – |
| post_message c=16 p50 ms | 77.6 [73.5–78.1] | – |
| post_message c=16 p99 ms | 213 [190–238] | – |
| post_message c=64 req/s | 202 [202–203] | – |
| post_message c=64 p50 ms | 309 [306–312] | – |
| post_message c=64 p99 ms | 474 [451–477] | – |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Rust adv. |
|---|---|---|
- reference: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Rust adv. |
|---|---|---|

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Rails | Rust adv. |
|---|---|---|
| POST with attachment (ms) | – | – |
| then GET thumb → 200 (ms) | – | – |
| POST → thumbnail served (ms) | – | – |

### Memory during cable fan-out, by process (MB, peak within the phase)

App process: Rails' Puma master and workers (Action Cable runs in them), or Rust's one campfire
process (its front server included). Pss counts pages shared between forked workers once;
RssAnon counts them in every process.

| Metric | Rails | Rust adv. |
|---|---|---|
