```
date: 2026-10-05T17:11:18+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 
rust extra env: 
user agent: (none)
reference image: campfire-reference:app sha256:0701d9b06ec642db9cdac8efc2854ba0e7f33d404af39d814acbc0d56323f6b0 2026-10-05T17:10:33.410393286+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: reference 3. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust adv. |
|---|---|---|
| cold start: docker run → /up 200 (ms) | 3,558 [3,521–3,596] | – |
| idle memory.current (MB) | 305 [297–305] | – |
| idle anon (MB) | 285 [278–285] | – |
| peak memory.current under load (MB) | 922 [897–959] | – |
| peak anon under load (MB) | 809 [805–827] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust adv. |
|---|---|---|
| room_show c=1 req/s | 92.3 [89.8–92.7] | – |
| room_show c=1 p50 ms | 10.5 [10.4–10.5] | – |
| room_show c=1 p99 ms | 13.0 [12.7–25.5] | – |
| room_show c=16 req/s | 223 [221–228] | – |
| room_show c=16 p50 ms | 71.7 [64.5–72.8] | – |
| room_show c=16 p99 ms | 148 [142–162] | – |
| room_show c=64 req/s | 194 [192–213] | – |
| room_show c=64 p50 ms | 334 [297–335] | – |
| room_show c=64 p99 ms | 396 [393–411] | – |
| messages_page c=1 req/s | 164 [163–164] | – |
| messages_page c=1 p50 ms | 5.93 [5.79–6.01] | – |
| messages_page c=1 p99 ms | 8.19 [7.39–13.94] | – |
| messages_page c=16 req/s | 373 [360–382] | – |
| messages_page c=16 p50 ms | 46.6 [43.8–47.0] | – |
| messages_page c=16 p99 ms | 89.5 [83.1–89.8] | – |
| messages_page c=64 req/s | 339 [337–364] | – |
| messages_page c=64 p50 ms | 182 [169–183] | – |
| messages_page c=64 p99 ms | 268 [252–272] | – |
| sidebar c=1 req/s | 202 [197–212] | – |
| sidebar c=1 p50 ms | 4.82 [4.60–4.98] | – |
| sidebar c=1 p99 ms | 6.48 [6.42–6.56] | – |
| sidebar c=16 req/s | 463 [459–496] | – |
| sidebar c=16 p50 ms | 34.0 [31.0–34.5] | – |
| sidebar c=16 p99 ms | 61.8 [60.6–62.4] | – |
| sidebar c=64 req/s | 408 [376–486] | – |
| sidebar c=64 p50 ms | 147 [123–169] | – |
| sidebar c=64 p99 ms | 230 [226–233] | – |
| search c=1 req/s | 155 [154–167] | – |
| search c=1 p50 ms | 6.31 [5.88–6.47] | – |
| search c=1 p99 ms | 7.80 [7.68–7.86] | – |
| search c=16 req/s | 366 [359–384] | – |
| search c=16 p50 ms | 43.0 [40.6–44.3] | – |
| search c=16 p99 ms | 79.1 [73.9–83.2] | – |
| search c=64 req/s | 330 [310–382] | – |
| search c=64 p50 ms | 183 [172–205] | – |
| search c=64 p99 ms | 270 [207–277] | – |
| avatar c=1 req/s | 18,247 [18,202–18,330] | – |
| avatar c=1 p50 ms | 0.05 [0.05–0.05] | – |
| avatar c=1 p99 ms | 0.12 [0.11–0.12] | – |
| avatar c=16 req/s | 62,365 [61,676–63,531] | – |
| avatar c=16 p50 ms | 0.17 [0.17–0.17] | – |
| avatar c=16 p99 ms | 1.31 [1.26–1.32] | – |
| avatar c=64 req/s | 51,427 [51,142–51,428] | – |
| avatar c=64 p50 ms | 0.48 [0.47–0.48] | – |
| avatar c=64 p99 ms | 7.63 [7.57–7.64] | – |
| static_css c=1 req/s | 23,629 [23,528–24,015] | – |
| static_css c=1 p50 ms | 0.04 [0.04–0.04] | – |
| static_css c=1 p99 ms | 0.09 [0.08–0.09] | – |
| static_css c=16 req/s | 85,819 [84,284–86,155] | – |
| static_css c=16 p50 ms | 0.13 [0.13–0.13] | – |
| static_css c=16 p99 ms | 0.94 [0.93–0.97] | – |
| static_css c=64 req/s | 72,496 [72,150–73,066] | – |
| static_css c=64 p50 ms | 0.43 [0.42–0.44] | – |
| static_css c=64 p99 ms | 5.10 [5.04–5.22] | – |
| up c=1 req/s | 1,523 [1,510–1,584] | – |
| up c=1 p50 ms | 0.58 [0.57–0.59] | – |
| up c=1 p99 ms | 1.79 [1.11–1.79] | – |
| up c=16 req/s | 3,480 [3,451–3,546] | – |
| up c=16 p50 ms | 4.43 [4.42–4.51] | – |
| up c=16 p99 ms | 8.51 [8.45–8.82] | – |
| up c=64 req/s | 3,430 [3,417–3,480] | – |
| up c=64 p50 ms | 18.7 [18.2–18.7] | – |
| up c=64 p99 ms | 27.2 [26.7–27.6] | – |
| post_message c=1 req/s | 114 [105–115] | – |
| post_message c=1 p50 ms | 7.86 [7.74–8.14] | – |
| post_message c=1 p99 ms | 31.6 [29.1–35.4] | – |
| post_message c=16 req/s | 185 [184–197] | – |
| post_message c=16 p50 ms | 75.9 [74.1–77.4] | – |
| post_message c=16 p99 ms | 217 [201–253] | – |
| post_message c=64 req/s | 199 [196–199] | – |
| post_message c=64 p50 ms | 314 [305–324] | – |
| post_message c=64 p99 ms | 481 [455–490] | – |

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
