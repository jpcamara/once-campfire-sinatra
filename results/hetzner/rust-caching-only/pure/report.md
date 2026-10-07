```
date: 2026-10-07T15:13:04+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
reference image: campfire-reference:app sha256:0701d9b06ec642db9cdac8efc2854ba0e7f33d404af39d814acbc0d56323f6b0 2026-10-05T17:10:33.410393286+02:00
rails-opt image: campfire-reference:rails-opt sha256:6f520516328aa2a27175662c32aed1c8c7d432e7b5e8b0ec8f578edfc542ec3b 2026-10-07T15:03:20.686141338+02:00
sinatra image: campfire-sinatra:app sha256:5a4251f6788448a44bb213f11a821a7e17b219fbb024004e2d09208918118726 2026-10-07T15:02:52.186225614+02:00
rage image: campfire-rage:app sha256:9a8fa62006cb18e3ccb9fc55ed3a093f48a6794b041ae9303d4ce31c0c7e0af9 2026-10-07T15:02:58.993474214+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: reference 3. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust adv. |
|---|---|---|
| cold start: docker run → /up 200 (ms) | 3,573 [3,551–3,610] | – |
| idle memory.current (MB) | 304 [301–307] | – |
| idle anon (MB) | 284 [281–288] | – |
| peak memory.current under load (MB) | 931 [890–963] | – |
| peak anon under load (MB) | 830 [804–871] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust adv. |
|---|---|---|
| room_show c=1 req/s | 90.2 [88.4–92.1] | – |
| room_show c=1 p50 ms | 10.5 [10.2–10.9] | – |
| room_show c=1 p99 ms | 13.4 [13.0–22.2] | – |
| room_show c=16 req/s | 221 [219–225] | – |
| room_show c=16 p50 ms | 74.6 [70.8–81.0] | – |
| room_show c=16 p99 ms | 147 [128–166] | – |
| room_show c=64 req/s | 193 [192–217] | – |
| room_show c=64 p50 ms | 328 [292–336] | – |
| room_show c=64 p99 ms | 394 [388–404] | – |
| messages_page c=1 req/s | 163 [160–168] | – |
| messages_page c=1 p50 ms | 6.00 [5.85–6.12] | – |
| messages_page c=1 p99 ms | 7.63 [7.26–7.88] | – |
| messages_page c=16 req/s | 365 [363–378] | – |
| messages_page c=16 p50 ms | 42.3 [42.1–46.2] | – |
| messages_page c=16 p99 ms | 91.3 [88.4–107.8] | – |
| messages_page c=64 req/s | 338 [332–357] | – |
| messages_page c=64 p50 ms | 185 [178–187] | – |
| messages_page c=64 p99 ms | 263 [240–264] | – |
| sidebar c=1 req/s | 200 [195–207] | – |
| sidebar c=1 p50 ms | 4.88 [4.71–5.04] | – |
| sidebar c=1 p99 ms | 6.61 [6.50–6.67] | – |
| sidebar c=16 req/s | 467 [463–486] | – |
| sidebar c=16 p50 ms | 32.6 [32.2–34.5] | – |
| sidebar c=16 p99 ms | 61.0 [58.2–63.5] | – |
| sidebar c=64 req/s | 408 [404–484] | – |
| sidebar c=64 p50 ms | 142 [129–152] | – |
| sidebar c=64 p99 ms | 215 [183–225] | – |
| search c=1 req/s | 158 [154–163] | – |
| search c=1 p50 ms | 6.21 [5.97–6.42] | – |
| search c=1 p99 ms | 7.97 [7.78–8.51] | – |
| search c=16 req/s | 368 [366–381] | – |
| search c=16 p50 ms | 41.5 [40.0–42.4] | – |
| search c=16 p99 ms | 85.7 [84.5–85.7] | – |
| search c=64 req/s | 326 [326–375] | – |
| search c=64 p50 ms | 186 [165–194] | – |
| search c=64 p99 ms | 259 [231–287] | – |
| avatar c=1 req/s | 18,191 [18,189–18,557] | – |
| avatar c=1 p50 ms | 0.05 [0.05–0.05] | – |
| avatar c=1 p99 ms | 0.12 [0.11–0.12] | – |
| avatar c=16 req/s | 62,433 [62,303–62,811] | – |
| avatar c=16 p50 ms | 0.17 [0.17–0.17] | – |
| avatar c=16 p99 ms | 1.29 [1.29–1.29] | – |
| avatar c=64 req/s | 50,691 [50,510–50,957] | – |
| avatar c=64 p50 ms | 0.46 [0.45–0.47] | – |
| avatar c=64 p99 ms | 7.77 [7.67–7.89] | – |
| static_css c=1 req/s | 23,440 [23,022–23,949] | – |
| static_css c=1 p50 ms | 0.04 [0.04–0.04] | – |
| static_css c=1 p99 ms | 0.09 [0.09–0.09] | – |
| static_css c=16 req/s | 83,894 [83,877–85,174] | – |
| static_css c=16 p50 ms | 0.13 [0.13–0.13] | – |
| static_css c=16 p99 ms | 0.98 [0.97–0.99] | – |
| static_css c=64 req/s | 72,537 [72,115–72,681] | – |
| static_css c=64 p50 ms | 0.43 [0.43–0.43] | – |
| static_css c=64 p99 ms | 5.20 [5.18–5.20] | – |
| up c=1 req/s | 1,548 [1,506–1,561] | – |
| up c=1 p50 ms | 0.58 [0.58–0.59] | – |
| up c=1 p99 ms | 1.72 [1.12–1.82] | – |
| up c=16 req/s | 3,472 [3,426–3,526] | – |
| up c=16 p50 ms | 4.49 [4.41–4.50] | – |
| up c=16 p99 ms | 8.97 [8.70–9.34] | – |
| up c=64 req/s | 3,463 [3,442–3,471] | – |
| up c=64 p50 ms | 18.4 [18.3–18.5] | – |
| up c=64 p99 ms | 27.6 [27.5–28.0] | – |
| post_message c=1 req/s | 113 [100–114] | – |
| post_message c=1 p50 ms | 7.97 [7.92–8.15] | – |
| post_message c=1 p99 ms | 34.6 [28.7–35.1] | – |
| post_message c=16 req/s | 196 [188–201] | – |
| post_message c=16 p50 ms | 70.0 [66.4–71.9] | – |
| post_message c=16 p99 ms | 219 [207–223] | – |
| post_message c=64 req/s | 199 [199–207] | – |
| post_message c=64 p50 ms | 315 [303–320] | – |
| post_message c=64 p99 ms | 449 [439–454] | – |

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
