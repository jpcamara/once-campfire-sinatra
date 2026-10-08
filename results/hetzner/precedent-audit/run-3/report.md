```
date: 2026-10-08T02:55:21+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
sinatra image: campfire-sinatra:app sha256:4f4bbaf837cfc27c84131a57a6bc531a17e55d359d3c135b487c61e98ab5892c 2026-10-08T00:02:42.862560516+02:00
rage image: campfire-rage:app sha256:fec54a77a520a3121a8a5d20c4b2a4feadc6476a7119a55a0276551fce3fa5d8 2026-10-08T00:13:15.796284949+02:00
rust image: campfire-rust:app sha256:ecb3890f2706b5cec162be650e18c22d15d1627382bdba574c36a123975fab8b 2026-10-07T16:29:31.789282932+02:00
reference image: campfire-reference:app sha256:0701d9b06ec642db9cdac8efc2854ba0e7f33d404af39d814acbc0d56323f6b0 2026-10-05T17:10:33.410393286+02:00
rails-opt image: campfire-reference:rails-opt sha256:b7dbb13afbe430c2229705cbef98a4a0ba17705d77f8a530c49d07626b46f670 2026-10-08T00:28:30.899881926+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: reference 1, rust 1. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 3,698 | 278 | 13.3× |
| idle memory.current (MB) | 295 | 15.0 | 19.7× |
| idle anon (MB) | 276 | 13.0 | 21.2× |
| peak memory.current under load (MB) | 1,540 | 272 | 5.7× |
| peak anon under load (MB) | 1,442 | 101 | 14.3× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| room_show c=1 req/s | 88.5 | 5,453 | 61.6× |
| room_show c=1 p50 ms | 10.5 | 0.18 | 58.7× |
| room_show c=1 p99 ms | 23.3 | 0.27 | 85.4× |
| room_show c=16 req/s | 218 | 21,155 | 97.0× |
| room_show c=16 p50 ms | 69.1 | 0.73 | 94.0× |
| room_show c=16 p99 ms | 138 | 1.33 | 103.4× |
| room_show c=64 req/s | 219 | 21,884 | 99.9× |
| room_show c=64 p50 ms | 295 | 2.85 | 103.2× |
| room_show c=64 p99 ms | 385 | 5.13 | 75.0× |
| messages_page c=1 req/s | 165 | 5,979 | 36.2× |
| messages_page c=1 p50 ms | 5.94 | 0.16 | 36.2× |
| messages_page c=1 p99 ms | 7.48 | 0.23 | 32.2× |
| messages_page c=16 req/s | 375 | 23,490 | 62.7× |
| messages_page c=16 p50 ms | 42.0 | 0.67 | 63.0× |
| messages_page c=16 p99 ms | 89.5 | 1.13 | 79.0× |
| messages_page c=64 req/s | 354 | 24,401 | 68.9× |
| messages_page c=64 p50 ms | 180 | 2.57 | 70.2× |
| messages_page c=64 p99 ms | 243 | 4.43 | 54.9× |
| sidebar c=1 req/s | 205 | 5,130 | 25.0× |
| sidebar c=1 p50 ms | 4.79 | 0.19 | 25.1× |
| sidebar c=1 p99 ms | 6.58 | 0.28 | 23.3× |
| sidebar c=16 req/s | 483 | 20,528 | 42.5× |
| sidebar c=16 p50 ms | 31.9 | 0.75 | 42.4× |
| sidebar c=16 p99 ms | 61.6 | 1.41 | 43.7× |
| sidebar c=64 req/s | 480 | 21,607 | 45.0× |
| sidebar c=64 p50 ms | 137 | 2.88 | 47.5× |
| sidebar c=64 p99 ms | 205 | 5.38 | 38.1× |
| search c=1 req/s | 162 | 5,861 | 36.2× |
| search c=1 p50 ms | 6.03 | 0.17 | 35.9× |
| search c=1 p99 ms | 8.18 | 0.23 | 36.0× |
| search c=16 req/s | 383 | 21,379 | 55.8× |
| search c=16 p50 ms | 41.3 | 0.70 | 58.8× |
| search c=16 p99 ms | 84.3 | 1.52 | 55.6× |
| search c=64 req/s | 370 | 26,206 | 70.7× |
| search c=64 p50 ms | 168 | 2.31 | 72.7× |
| search c=64 p99 ms | 245 | 4.65 | 52.7× |
| avatar c=1 req/s | 18,163 | 38,658 | 2.1× |
| avatar c=1 p50 ms | 0.05 | 0.02 | 2.1× |
| avatar c=1 p99 ms | 0.12 | 0.03 | 3.5× |
| avatar c=16 req/s | 61,938 | 196,428 | 3.2× |
| avatar c=16 p50 ms | 0.17 | 0.07 | 2.4× |
| avatar c=16 p99 ms | 1.31 | 0.24 | 5.4× |
| avatar c=64 req/s | 50,676 | 198,645 | 3.9× |
| avatar c=64 p50 ms | 0.46 | 0.27 | 1.7× |
| avatar c=64 p99 ms | 7.84 | 1.74 | 4.5× |
| static_css c=1 req/s | 23,707 | 41,609 | 1.8× |
| static_css c=1 p50 ms | 0.04 | 0.02 | 1.7× |
| static_css c=1 p99 ms | 0.08 | 0.03 | 2.8× |
| static_css c=16 req/s | 84,239 | 210,037 | 2.5× |
| static_css c=16 p50 ms | 0.13 | 0.07 | 2.0× |
| static_css c=16 p99 ms | 0.95 | 0.23 | 4.2× |
| static_css c=64 req/s | 70,117 | 214,054 | 3.1× |
| static_css c=64 p50 ms | 0.42 | 0.26 | 1.6× |
| static_css c=64 p99 ms | 5.40 | 1.68 | 3.2× |
| up c=1 req/s | 1,547 | 23,845 | 15.4× |
| up c=1 p50 ms | 0.59 | 0.04 | 15.0× |
| up c=1 p99 ms | 1.17 | 0.06 | 18.6× |
| up c=16 req/s | 3,483 | 121,809 | 35.0× |
| up c=16 p50 ms | 4.50 | 0.13 | 34.6× |
| up c=16 p99 ms | 8.62 | 0.23 | 38.0× |
| up c=64 req/s | 3,440 | 125,735 | 36.5× |
| up c=64 p50 ms | 18.5 | 0.49 | 37.7× |
| up c=64 p99 ms | 27.3 | 1.04 | 26.3× |
| post_message c=1 req/s | 114 | 2,000 | 17.6× |
| post_message c=1 p50 ms | 7.89 | 0.44 | 17.9× |
| post_message c=1 p99 ms | 29.2 | 0.68 | 42.6× |
| post_message c=16 req/s | 198 | 4,109 | 20.7× |
| post_message c=16 p50 ms | 76.4 | 2.92 | 26.2× |
| post_message c=16 p99 ms | 187 | 37.2 | 5.0× |
| post_message c=64 req/s | 195 | 4,090 | 21.0× |
| post_message c=64 p50 ms | 316 | 11.9 | 26.5× |
| post_message c=64 p99 ms | 495 | 50.0 | 9.9× |

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
| 100 clients: paced post→one client p50 ms | 13.8 | 1.50 | 9.3× |
| 100 clients: paced post→all clients p50 ms | 19.9 | 1.74 | 11.4× |
| 100 clients: paced post→all clients p99 ms | 63.2 | 2.52 | 25.1× |
| 100 clients: max sustained msgs/s (delivered to all) | 72.6 | 2,235 | 30.8× |
| 100 clients: deliveries/s (client×message) | 7,262 | 223,533 | 30.8× |
| 100 clients: saturated post→all p50 ms | 54.7 | 2.02 | 27.2× |
| 100 clients: saturated POST p50 ms | 45.4 | 1.50 | 30.2× |
| 500 clients: subscribed | 500 | 500 | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.97 | 0.15 | 6.5× |
| 500 clients: paced post→one client p50 ms | 28.5 | 2.98 | 9.6× |
| 500 clients: paced post→all clients p50 ms | 54.4 | 4.70 | 11.6× |
| 500 clients: paced post→all clients p99 ms | 85.5 | 22.2 | 3.8× |
| 500 clients: max sustained msgs/s (delivered to all) | 20.3 | 711 | 35.0× |
| 500 clients: deliveries/s (client×message) | 10,129 | 355,401 | 35.1× |
| 500 clients: saturated post→all p50 ms | 185 | 11.8 | 15.7× |
| 500 clients: saturated POST p50 ms | 179 | 5.18 | 34.5× |
| 1000 clients: subscribed | 1,000 | 1,000 | 1.0× |
| 1000 clients: connect+subscribe all (s) | 1.95 | 0.20 | 9.8× |
| 1000 clients: paced post→one client p50 ms | 42.0 | 4.29 | 9.8× |
| 1000 clients: paced post→all clients p50 ms | 89.9 | 7.29 | 12.3× |
| 1000 clients: paced post→all clients p99 ms | 184 | 26.7 | 6.9× |
| 1000 clients: max sustained msgs/s (delivered to all) | 12.4 | 376 | 30.3× |
| 1000 clients: deliveries/s (client×message) | 12,427 | 375,701 | 30.2× |
| 1000 clients: saturated post→all p50 ms | 272 | 22.5 | 12.1× |
| 1000 clients: saturated POST p50 ms | 298 | 10.4 | 28.7× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| POST with attachment (ms) | – | – | – |
| then GET thumb → 200 (ms) | – | – | – |
| POST → thumbnail served (ms) | – | – | – |

### Memory during cable fan-out, by process (MB, peak within the phase)

App process: Rails' Puma master and workers (Action Cable runs in them), or Rust's one campfire
process (its front server included). Pss counts pages shared between forked workers once;
RssAnon counts them in every process.

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 547 | 121 | 4.5× |
| 100 clients, all subscribed, idle: app process RssAnon | 692 | 98.7 | 7.0× |
| 100 clients, all subscribed, idle: app + Redis + Thruster Pss | 583 | 121 | 4.8× |
| 100 clients, all subscribed, idle: whole container Pss | 878 | 121 | 7.3× |
| 100 clients, saturated fan-out: app process Pss | 648 | 120 | 5.4× |
| 100 clients, saturated fan-out: app process RssAnon | 792 | 98.2 | 8.1× |
| 100 clients, saturated fan-out: app + Redis + Thruster Pss | 696 | 120 | 5.8× |
| 100 clients, saturated fan-out: whole container Pss | 992 | 120 | 8.3× |
| 500 clients, all subscribed, idle: app process Pss | 625 | 117 | 5.3× |
| 500 clients, all subscribed, idle: app process RssAnon | 766 | 95.2 | 8.0× |
| 500 clients, all subscribed, idle: app + Redis + Thruster Pss | 690 | 117 | 5.9× |
| 500 clients, all subscribed, idle: whole container Pss | 986 | 117 | 8.4× |
| 500 clients, saturated fan-out: app process Pss | 719 | 118 | 6.1× |
| 500 clients, saturated fan-out: app process RssAnon | 860 | 95.8 | 9.0× |
| 500 clients, saturated fan-out: app + Redis + Thruster Pss | 794 | 118 | 6.7× |
| 500 clients, saturated fan-out: whole container Pss | 1,089 | 118 | 9.2× |
| 1000 clients, all subscribed, idle: app process Pss | 644 | 123 | 5.3× |
| 1000 clients, all subscribed, idle: app process RssAnon | 784 | 101 | 7.8× |
| 1000 clients, all subscribed, idle: app + Redis + Thruster Pss | 778 | 123 | 6.3× |
| 1000 clients, all subscribed, idle: whole container Pss | 1,074 | 123 | 8.8× |
| 1000 clients, saturated fan-out: app process Pss | 1,059 | 123 | 8.6× |
| 1000 clients, saturated fan-out: app process RssAnon | 1,199 | 101 | 11.9× |
| 1000 clients, saturated fan-out: app + Redis + Thruster Pss | 1,198 | 123 | 9.8× |
| 1000 clients, saturated fan-out: whole container Pss | 1,491 | 123 | 12.1× |
