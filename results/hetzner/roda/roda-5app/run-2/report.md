```
date: 2026-10-08T06:33:41+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
roda image: campfire-roda:app sha256:e1c9836cfb6fc66661f7a59cf899e6cec80d07c49e4d9e285b8d69de71eca2ee 2026-10-08T02:24:48.338647722+02:00
rust image: campfire-rust:app sha256:ecb3890f2706b5cec162be650e18c22d15d1627382bdba574c36a123975fab8b 2026-10-07T16:29:31.789282932+02:00
reference image: campfire-reference:app sha256:0701d9b06ec642db9cdac8efc2854ba0e7f33d404af39d814acbc0d56323f6b0 2026-10-05T17:10:33.410393286+02:00
sinatra image: campfire-sinatra:app sha256:4f4bbaf837cfc27c84131a57a6bc531a17e55d359d3c135b487c61e98ab5892c 2026-10-08T00:02:42.862560516+02:00
rage image: campfire-rage:app sha256:fec54a77a520a3121a8a5d20c4b2a4feadc6476a7119a55a0276551fce3fa5d8 2026-10-08T00:13:15.796284949+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: reference 1, rust 1. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 3,679 | 287 | 12.8× |
| idle memory.current (MB) | 301 | 15.0 | 20.1× |
| idle anon (MB) | 282 | 13.0 | 21.7× |
| peak memory.current under load (MB) | 1,578 | 357 | 4.4× |
| peak anon under load (MB) | 1,476 | 259 | 5.7× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| room_show c=1 req/s | 92.2 | 5,452 | 59.1× |
| room_show c=1 p50 ms | 10.6 | 0.18 | 58.7× |
| room_show c=1 p99 ms | 12.5 | 0.27 | 46.9× |
| room_show c=16 req/s | 223 | 21,253 | 95.3× |
| room_show c=16 p50 ms | 71.1 | 0.73 | 97.3× |
| room_show c=16 p99 ms | 159 | 1.31 | 121.0× |
| room_show c=64 req/s | 186 | 21,894 | 117.4× |
| room_show c=64 p50 ms | 345 | 2.85 | 120.8× |
| room_show c=64 p99 ms | 426 | 5.14 | 82.9× |
| messages_page c=1 req/s | 163 | 6,112 | 37.5× |
| messages_page c=1 p50 ms | 6.02 | 0.16 | 37.4× |
| messages_page c=1 p99 ms | 7.48 | 0.23 | 32.3× |
| messages_page c=16 req/s | 362 | 23,634 | 65.3× |
| messages_page c=16 p50 ms | 43.6 | 0.66 | 65.9× |
| messages_page c=16 p99 ms | 90.4 | 1.13 | 80.0× |
| messages_page c=64 req/s | 340 | 24,542 | 72.3× |
| messages_page c=64 p50 ms | 181 | 2.56 | 70.8× |
| messages_page c=64 p99 ms | 268 | 4.40 | 60.8× |
| sidebar c=1 req/s | 205 | 5,136 | 25.0× |
| sidebar c=1 p50 ms | 4.78 | 0.19 | 25.0× |
| sidebar c=1 p99 ms | 6.44 | 0.28 | 22.8× |
| sidebar c=16 req/s | 467 | 20,652 | 44.2× |
| sidebar c=16 p50 ms | 35.1 | 0.75 | 46.9× |
| sidebar c=16 p99 ms | 59.8 | 1.40 | 42.7× |
| sidebar c=64 req/s | 429 | 21,569 | 50.2× |
| sidebar c=64 p50 ms | 135 | 2.88 | 46.7× |
| sidebar c=64 p99 ms | 240 | 5.40 | 44.5× |
| search c=1 req/s | 158 | 5,834 | 37.0× |
| search c=1 p50 ms | 6.23 | 0.17 | 36.9× |
| search c=1 p99 ms | 7.95 | 0.23 | 34.4× |
| search c=16 req/s | 372 | 21,384 | 57.5× |
| search c=16 p50 ms | 32.4 | 0.70 | 46.2× |
| search c=16 p99 ms | 113 | 1.51 | 74.8× |
| search c=64 req/s | 344 | 26,566 | 77.2× |
| search c=64 p50 ms | 178 | 2.29 | 77.9× |
| search c=64 p99 ms | 278 | 4.54 | 61.2× |
| avatar c=1 req/s | 17,944 | 39,406 | 2.2× |
| avatar c=1 p50 ms | 0.05 | 0.02 | 2.2× |
| avatar c=1 p99 ms | 0.12 | 0.03 | 3.5× |
| avatar c=16 req/s | 61,696 | 191,682 | 3.1× |
| avatar c=16 p50 ms | 0.17 | 0.07 | 2.4× |
| avatar c=16 p99 ms | 1.30 | 0.26 | 4.9× |
| avatar c=64 req/s | 50,611 | 199,430 | 3.9× |
| avatar c=64 p50 ms | 0.47 | 0.28 | 1.7× |
| avatar c=64 p99 ms | 7.77 | 1.66 | 4.7× |
| static_css c=1 req/s | 22,581 | 41,896 | 1.9× |
| static_css c=1 p50 ms | 0.04 | 0.02 | 1.8× |
| static_css c=1 p99 ms | 0.09 | 0.03 | 3.1× |
| static_css c=16 req/s | 84,500 | 207,703 | 2.5× |
| static_css c=16 p50 ms | 0.13 | 0.07 | 1.9× |
| static_css c=16 p99 ms | 0.96 | 0.22 | 4.4× |
| static_css c=64 req/s | 71,477 | 214,528 | 3.0× |
| static_css c=64 p50 ms | 0.42 | 0.26 | 1.7× |
| static_css c=64 p99 ms | 5.19 | 1.80 | 2.9× |
| up c=1 req/s | 1,520 | 24,276 | 16.0× |
| up c=1 p50 ms | 0.59 | 0.04 | 15.1× |
| up c=1 p99 ms | 1.23 | 0.06 | 21.6× |
| up c=16 req/s | 3,362 | 121,298 | 36.1× |
| up c=16 p50 ms | 4.55 | 0.13 | 34.7× |
| up c=16 p99 ms | 9.54 | 0.23 | 41.5× |
| up c=64 req/s | 3,406 | 120,388 | 35.3× |
| up c=64 p50 ms | 18.6 | 0.52 | 36.2× |
| up c=64 p99 ms | 28.8 | 1.10 | 26.3× |
| post_message c=1 req/s | 108 | 2,031 | 18.9× |
| post_message c=1 p50 ms | 7.89 | 0.44 | 17.9× |
| post_message c=1 p99 ms | 31.4 | 0.79 | 39.8× |
| post_message c=16 req/s | 197 | 4,310 | 21.9× |
| post_message c=16 p50 ms | 75.3 | 2.90 | 25.9× |
| post_message c=16 p99 ms | 196 | 35.8 | 5.5× |
| post_message c=64 req/s | 204 | 4,034 | 19.8× |
| post_message c=64 p50 ms | 310 | 12.0 | 25.8× |
| post_message c=64 p99 ms | 443 | 51.9 | 8.5× |

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
| 100 clients: paced post→one client p50 ms | 14.1 | 1.70 | 8.3× |
| 100 clients: paced post→all clients p50 ms | 18.2 | 2.00 | 9.1× |
| 100 clients: paced post→all clients p99 ms | 58.4 | 2.60 | 22.4× |
| 100 clients: max sustained msgs/s (delivered to all) | 74.9 | 2,268 | 30.3× |
| 100 clients: deliveries/s (client×message) | 7,491 | 226,771 | 30.3× |
| 100 clients: saturated post→all p50 ms | 57.1 | 1.95 | 29.3× |
| 100 clients: saturated POST p50 ms | 46.5 | 1.50 | 31.0× |
| 500 clients: subscribed | 500 | 500 | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.89 | 0.14 | 6.4× |
| 500 clients: paced post→one client p50 ms | 25.8 | 2.88 | 9.0× |
| 500 clients: paced post→all clients p50 ms | 50.0 | 4.17 | 12.0× |
| 500 clients: paced post→all clients p99 ms | 106 | 12.8 | 8.3× |
| 500 clients: max sustained msgs/s (delivered to all) | 23.7 | 702 | 29.6× |
| 500 clients: deliveries/s (client×message) | 11,858 | 351,039 | 29.6× |
| 500 clients: saturated post→all p50 ms | 137 | 11.8 | 11.6× |
| 500 clients: saturated POST p50 ms | 164 | 5.23 | 31.4× |
| 1000 clients: subscribed | 1,000 | 1,000 | 1.0× |
| 1000 clients: connect+subscribe all (s) | 1.75 | 0.17 | 10.3× |
| 1000 clients: paced post→one client p50 ms | 42.0 | 4.20 | 10.0× |
| 1000 clients: paced post→all clients p50 ms | 87.4 | 7.17 | 12.2× |
| 1000 clients: paced post→all clients p99 ms | 167 | 11.1 | 15.1× |
| 1000 clients: max sustained msgs/s (delivered to all) | 12.6 | 374 | 29.7× |
| 1000 clients: deliveries/s (client×message) | 12,592 | 374,250 | 29.7× |
| 1000 clients: saturated post→all p50 ms | 283 | 23.1 | 12.2× |
| 1000 clients: saturated POST p50 ms | 243 | 10.3 | 23.6× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| POST with attachment (ms) | 94.0 | 34.8 | 2.7× |
| then GET thumb → 200 (ms) | 0.40 | 0.30 | 1.3× |
| POST → thumbnail served (ms) | 94.4 | 35.1 | 2.7× |

### Memory during cable fan-out, by process (MB, peak within the phase)

App process: Rails' Puma master and workers (Action Cable runs in them), or Rust's one campfire
process (its front server included). Pss counts pages shared between forked workers once;
RssAnon counts them in every process.

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 569 | 122 | 4.7× |
| 100 clients, all subscribed, idle: app process RssAnon | 715 | 99.9 | 7.2× |
| 100 clients, all subscribed, idle: app + Redis + Thruster Pss | 606 | 122 | 5.0× |
| 100 clients, all subscribed, idle: whole container Pss | 900 | 122 | 7.4× |
| 100 clients, saturated fan-out: app process Pss | 696 | 122 | 5.7× |
| 100 clients, saturated fan-out: app process RssAnon | 838 | 99.9 | 8.4× |
| 100 clients, saturated fan-out: app + Redis + Thruster Pss | 744 | 122 | 6.1× |
| 100 clients, saturated fan-out: whole container Pss | 1,039 | 122 | 8.5× |
| 500 clients, all subscribed, idle: app process Pss | 626 | 113 | 5.5× |
| 500 clients, all subscribed, idle: app process RssAnon | 767 | 91.0 | 8.4× |
| 500 clients, all subscribed, idle: app + Redis + Thruster Pss | 691 | 113 | 6.1× |
| 500 clients, all subscribed, idle: whole container Pss | 987 | 113 | 8.7× |
| 500 clients, saturated fan-out: app process Pss | 865 | 113 | 7.7× |
| 500 clients, saturated fan-out: app process RssAnon | 1,006 | 90.9 | 11.1× |
| 500 clients, saturated fan-out: app + Redis + Thruster Pss | 940 | 113 | 8.3× |
| 500 clients, saturated fan-out: whole container Pss | 1,231 | 113 | 10.9× |
| 1000 clients, all subscribed, idle: app process Pss | 706 | 119 | 5.9× |
| 1000 clients, all subscribed, idle: app process RssAnon | 846 | 96.8 | 8.7× |
| 1000 clients, all subscribed, idle: app + Redis + Thruster Pss | 806 | 119 | 6.8× |
| 1000 clients, all subscribed, idle: whole container Pss | 1,101 | 119 | 9.3× |
| 1000 clients, saturated fan-out: app process Pss | 1,017 | 119 | 8.6× |
| 1000 clients, saturated fan-out: app process RssAnon | 1,156 | 96.9 | 11.9× |
| 1000 clients, saturated fan-out: app + Redis + Thruster Pss | 1,126 | 119 | 9.5× |
| 1000 clients, saturated fan-out: whole container Pss | 1,418 | 119 | 11.9× |
