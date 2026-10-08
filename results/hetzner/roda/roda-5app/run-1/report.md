```
date: 2026-10-08T06:04:18+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
reference image: campfire-reference:app sha256:0701d9b06ec642db9cdac8efc2854ba0e7f33d404af39d814acbc0d56323f6b0 2026-10-05T17:10:33.410393286+02:00
sinatra image: campfire-sinatra:app sha256:4f4bbaf837cfc27c84131a57a6bc531a17e55d359d3c135b487c61e98ab5892c 2026-10-08T00:02:42.862560516+02:00
rage image: campfire-rage:app sha256:fec54a77a520a3121a8a5d20c4b2a4feadc6476a7119a55a0276551fce3fa5d8 2026-10-08T00:13:15.796284949+02:00
roda image: campfire-roda:app 
rust image: campfire-rust:app sha256:ecb3890f2706b5cec162be650e18c22d15d1627382bdba574c36a123975fab8b 2026-10-07T16:29:31.789282932+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: reference 1, rust 1. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 3,636 | 348 | 10.4× |
| idle memory.current (MB) | 305 | 15.0 | 20.3× |
| idle anon (MB) | 285 | 13.0 | 21.9× |
| peak memory.current under load (MB) | 1,608 | 372 | 4.3× |
| peak anon under load (MB) | 1,505 | 274 | 5.5× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| room_show c=1 req/s | 92.9 | 5,468 | 58.9× |
| room_show c=1 p50 ms | 10.5 | 0.18 | 58.6× |
| room_show c=1 p99 ms | 12.3 | 0.27 | 46.1× |
| room_show c=16 req/s | 216 | 21,206 | 98.0× |
| room_show c=16 p50 ms | 71.4 | 0.73 | 97.4× |
| room_show c=16 p99 ms | 127 | 1.32 | 96.0× |
| room_show c=64 req/s | 185 | 22,004 | 118.7× |
| room_show c=64 p50 ms | 275 | 2.84 | 97.0× |
| room_show c=64 p99 ms | 591 | 5.07 | 116.6× |
| messages_page c=1 req/s | 164 | 6,043 | 36.8× |
| messages_page c=1 p50 ms | 5.98 | 0.16 | 36.9× |
| messages_page c=1 p99 ms | 7.44 | 0.24 | 31.5× |
| messages_page c=16 req/s | 373 | 23,652 | 63.4× |
| messages_page c=16 p50 ms | 43.3 | 0.66 | 65.5× |
| messages_page c=16 p99 ms | 92.9 | 1.13 | 82.3× |
| messages_page c=64 req/s | 329 | 24,465 | 74.3× |
| messages_page c=64 p50 ms | 190 | 2.56 | 74.2× |
| messages_page c=64 p99 ms | 276 | 4.42 | 62.5× |
| sidebar c=1 req/s | 208 | 5,104 | 24.5× |
| sidebar c=1 p50 ms | 4.68 | 0.19 | 24.5× |
| sidebar c=1 p99 ms | 6.45 | 0.30 | 21.6× |
| sidebar c=16 req/s | 480 | 20,760 | 43.2× |
| sidebar c=16 p50 ms | 32.2 | 0.75 | 43.2× |
| sidebar c=16 p99 ms | 61.7 | 1.39 | 44.5× |
| sidebar c=64 req/s | 459 | 21,615 | 47.1× |
| sidebar c=64 p50 ms | 133 | 2.88 | 46.1× |
| sidebar c=64 p99 ms | 217 | 5.42 | 40.0× |
| search c=1 req/s | 164 | 5,917 | 36.1× |
| search c=1 p50 ms | 6.00 | 0.17 | 35.9× |
| search c=1 p99 ms | 7.70 | 0.23 | 33.6× |
| search c=16 req/s | 373 | 21,361 | 57.3× |
| search c=16 p50 ms | 41.3 | 0.70 | 58.8× |
| search c=16 p99 ms | 74.6 | 1.52 | 49.1× |
| search c=64 req/s | 356 | 26,604 | 74.7× |
| search c=64 p50 ms | 171 | 2.28 | 75.0× |
| search c=64 p99 ms | 276 | 4.63 | 59.6× |
| avatar c=1 req/s | 17,779 | 39,479 | 2.2× |
| avatar c=1 p50 ms | 0.05 | 0.02 | 2.3× |
| avatar c=1 p99 ms | 0.12 | 0.03 | 3.8× |
| avatar c=16 req/s | 62,119 | 196,130 | 3.2× |
| avatar c=16 p50 ms | 0.17 | 0.07 | 2.4× |
| avatar c=16 p99 ms | 1.30 | 0.24 | 5.3× |
| avatar c=64 req/s | 50,244 | 195,821 | 3.9× |
| avatar c=64 p50 ms | 0.46 | 0.28 | 1.7× |
| avatar c=64 p99 ms | 7.83 | 1.71 | 4.6× |
| static_css c=1 req/s | 23,699 | 41,356 | 1.7× |
| static_css c=1 p50 ms | 0.04 | 0.02 | 1.7× |
| static_css c=1 p99 ms | 0.08 | 0.03 | 2.8× |
| static_css c=16 req/s | 83,144 | 209,923 | 2.5× |
| static_css c=16 p50 ms | 0.13 | 0.07 | 2.0× |
| static_css c=16 p99 ms | 1.00 | 0.23 | 4.4× |
| static_css c=64 req/s | 71,768 | 212,802 | 3.0× |
| static_css c=64 p50 ms | 0.42 | 0.26 | 1.6× |
| static_css c=64 p99 ms | 5.23 | 1.78 | 2.9× |
| up c=1 req/s | 1,527 | 23,695 | 15.5× |
| up c=1 p50 ms | 0.59 | 0.04 | 14.7× |
| up c=1 p99 ms | 1.19 | 0.06 | 21.3× |
| up c=16 req/s | 3,370 | 119,515 | 35.5× |
| up c=16 p50 ms | 4.59 | 0.13 | 34.8× |
| up c=16 p99 ms | 9.56 | 0.23 | 40.9× |
| up c=64 req/s | 3,427 | 122,638 | 35.8× |
| up c=64 p50 ms | 18.7 | 0.50 | 37.1× |
| up c=64 p99 ms | 26.5 | 1.06 | 25.0× |
| post_message c=1 req/s | 122 | 1,980 | 16.2× |
| post_message c=1 p50 ms | 7.45 | 0.44 | 16.9× |
| post_message c=1 p99 ms | 30.1 | 0.73 | 41.4× |
| post_message c=16 req/s | 203 | 4,059 | 20.0× |
| post_message c=16 p50 ms | 55.8 | 2.92 | 19.1× |
| post_message c=16 p99 ms | 237 | 38.5 | 6.2× |
| post_message c=64 req/s | 198 | 4,031 | 20.3× |
| post_message c=64 p50 ms | 317 | 11.9 | 26.7× |
| post_message c=64 p99 ms | 451 | 53.5 | 8.4× |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
- reference: none
- rust: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| 100 clients: subscribed | 100 | 100 | 1.0× |
| 100 clients: connect+subscribe all (s) | 0.32 | 0.06 | 5.3× |
| 100 clients: paced post→one client p50 ms | 14.8 | 1.64 | 9.0× |
| 100 clients: paced post→all clients p50 ms | 20.0 | 1.90 | 10.5× |
| 100 clients: paced post→all clients p99 ms | 53.0 | 6.39 | 8.3× |
| 100 clients: max sustained msgs/s (delivered to all) | 75.4 | 2,330 | 30.9× |
| 100 clients: deliveries/s (client×message) | 7,540 | 232,994 | 30.9× |
| 100 clients: saturated post→all p50 ms | 54.1 | 1.96 | 27.6× |
| 100 clients: saturated POST p50 ms | 45.3 | 1.44 | 31.4× |
| 500 clients: subscribed | 500 | 500 | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.85 | 0.12 | 7.1× |
| 500 clients: paced post→one client p50 ms | 26.7 | 2.85 | 9.3× |
| 500 clients: paced post→all clients p50 ms | 50.2 | 4.59 | 10.9× |
| 500 clients: paced post→all clients p99 ms | 134 | 12.8 | 10.4× |
| 500 clients: max sustained msgs/s (delivered to all) | 23.3 | 706 | 30.3× |
| 500 clients: deliveries/s (client×message) | 11,661 | 352,778 | 30.3× |
| 500 clients: saturated post→all p50 ms | 155 | 11.9 | 13.0× |
| 500 clients: saturated POST p50 ms | 163 | 5.22 | 31.2× |
| 1000 clients: subscribed | 1,000 | 1,000 | 1.0× |
| 1000 clients: connect+subscribe all (s) | 1.63 | 0.15 | 10.9× |
| 1000 clients: paced post→one client p50 ms | 42.1 | 3.93 | 10.7× |
| 1000 clients: paced post→all clients p50 ms | 87.4 | 6.99 | 12.5× |
| 1000 clients: paced post→all clients p99 ms | 168 | 10.6 | 15.9× |
| 1000 clients: max sustained msgs/s (delivered to all) | 12.4 | 377 | 30.4× |
| 1000 clients: deliveries/s (client×message) | 12,376 | 376,786 | 30.4× |
| 1000 clients: saturated post→all p50 ms | 262 | 23.3 | 11.3× |
| 1000 clients: saturated POST p50 ms | 291 | 10.3 | 28.4× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| POST with attachment (ms) | 65.0 | 35.4 | 1.8× |
| then GET thumb → 200 (ms) | 0.50 | 0.40 | 1.2× |
| POST → thumbnail served (ms) | 65.4 | 35.7 | 1.8× |

### Memory during cable fan-out, by process (MB, peak within the phase)

App process: Rails' Puma master and workers (Action Cable runs in them), or Rust's one campfire
process (its front server included). Pss counts pages shared between forked workers once;
RssAnon counts them in every process.

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 570 | 121 | 4.7× |
| 100 clients, all subscribed, idle: app process RssAnon | 716 | 99.1 | 7.2× |
| 100 clients, all subscribed, idle: app + Redis + Thruster Pss | 607 | 121 | 5.0× |
| 100 clients, all subscribed, idle: whole container Pss | 873 | 121 | 7.2× |
| 100 clients, saturated fan-out: app process Pss | 688 | 119 | 5.8× |
| 100 clients, saturated fan-out: app process RssAnon | 831 | 97.2 | 8.5× |
| 100 clients, saturated fan-out: app + Redis + Thruster Pss | 737 | 119 | 6.2× |
| 100 clients, saturated fan-out: whole container Pss | 1,003 | 119 | 8.4× |
| 500 clients, all subscribed, idle: app process Pss | 630 | 118 | 5.4× |
| 500 clients, all subscribed, idle: app process RssAnon | 772 | 95.9 | 8.0× |
| 500 clients, all subscribed, idle: app + Redis + Thruster Pss | 696 | 118 | 5.9× |
| 500 clients, all subscribed, idle: whole container Pss | 961 | 118 | 8.2× |
| 500 clients, saturated fan-out: app process Pss | 867 | 117 | 7.4× |
| 500 clients, saturated fan-out: app process RssAnon | 1,007 | 95.7 | 10.5× |
| 500 clients, saturated fan-out: app + Redis + Thruster Pss | 941 | 117 | 8.0× |
| 500 clients, saturated fan-out: whole container Pss | 1,207 | 117 | 10.3× |
| 1000 clients, all subscribed, idle: app process Pss | 707 | 127 | 5.6× |
| 1000 clients, all subscribed, idle: app process RssAnon | 847 | 105 | 8.1× |
| 1000 clients, all subscribed, idle: app + Redis + Thruster Pss | 838 | 127 | 6.6× |
| 1000 clients, all subscribed, idle: whole container Pss | 1,104 | 127 | 8.7× |
| 1000 clients, saturated fan-out: app process Pss | 1,075 | 124 | 8.6× |
| 1000 clients, saturated fan-out: app process RssAnon | 1,215 | 103 | 11.8× |
| 1000 clients, saturated fan-out: app + Redis + Thruster Pss | 1,211 | 124 | 9.7× |
| 1000 clients, saturated fan-out: whole container Pss | 1,475 | 124 | 11.9× |
