```
date: 2026-10-08T02:24:49+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
rage image: campfire-rage:app sha256:fec54a77a520a3121a8a5d20c4b2a4feadc6476a7119a55a0276551fce3fa5d8 2026-10-08T00:13:15.796284949+02:00
rust image: campfire-rust:app sha256:ecb3890f2706b5cec162be650e18c22d15d1627382bdba574c36a123975fab8b 2026-10-07T16:29:31.789282932+02:00
reference image: campfire-reference:app sha256:0701d9b06ec642db9cdac8efc2854ba0e7f33d404af39d814acbc0d56323f6b0 2026-10-05T17:10:33.410393286+02:00
rails-opt image: campfire-reference:rails-opt sha256:b7dbb13afbe430c2229705cbef98a4a0ba17705d77f8a530c49d07626b46f670 2026-10-08T00:28:30.899881926+02:00
sinatra image: campfire-sinatra:app sha256:4f4bbaf837cfc27c84131a57a6bc531a17e55d359d3c135b487c61e98ab5892c 2026-10-08T00:02:42.862560516+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: reference 1, rust 1. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 3,606 | 263 | 13.7× |
| idle memory.current (MB) | 303 | 15.0 | 20.2× |
| idle anon (MB) | 283 | 13.0 | 21.8× |
| peak memory.current under load (MB) | 1,388 | 257 | 5.4× |
| peak anon under load (MB) | 1,318 | 101 | 13.0× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| room_show c=1 req/s | 91.8 | 5,466 | 59.5× |
| room_show c=1 p50 ms | 10.8 | 0.18 | 60.3× |
| room_show c=1 p99 ms | 12.4 | 0.27 | 46.4× |
| room_show c=16 req/s | 221 | 21,253 | 96.0× |
| room_show c=16 p50 ms | 61.9 | 0.73 | 84.5× |
| room_show c=16 p99 ms | 187 | 1.32 | 141.6× |
| room_show c=64 req/s | 192 | 21,693 | 112.9× |
| room_show c=64 p50 ms | 339 | 2.88 | 117.9× |
| room_show c=64 p99 ms | 419 | 5.16 | 81.2× |
| messages_page c=1 req/s | 164 | 6,055 | 37.0× |
| messages_page c=1 p50 ms | 5.99 | 0.16 | 37.0× |
| messages_page c=1 p99 ms | 7.44 | 0.23 | 32.1× |
| messages_page c=16 req/s | 370 | 23,515 | 63.5× |
| messages_page c=16 p50 ms | 39.2 | 0.67 | 58.9× |
| messages_page c=16 p99 ms | 116 | 1.13 | 102.4× |
| messages_page c=64 req/s | 337 | 24,428 | 72.5× |
| messages_page c=64 p50 ms | 186 | 2.57 | 72.2× |
| messages_page c=64 p99 ms | 307 | 4.40 | 69.9× |
| sidebar c=1 req/s | 196 | 5,156 | 26.3× |
| sidebar c=1 p50 ms | 4.95 | 0.19 | 26.2× |
| sidebar c=1 p99 ms | 7.50 | 0.29 | 25.7× |
| sidebar c=16 req/s | 459 | 20,972 | 45.7× |
| sidebar c=16 p50 ms | 33.5 | 0.74 | 45.4× |
| sidebar c=16 p99 ms | 64.1 | 1.38 | 46.5× |
| sidebar c=64 req/s | 410 | 21,456 | 52.3× |
| sidebar c=64 p50 ms | 144 | 2.90 | 49.8× |
| sidebar c=64 p99 ms | 252 | 5.43 | 46.4× |
| search c=1 req/s | 154 | 5,796 | 37.7× |
| search c=1 p50 ms | 6.42 | 0.17 | 37.8× |
| search c=1 p99 ms | 8.01 | 0.23 | 34.1× |
| search c=16 req/s | 367 | 21,254 | 57.9× |
| search c=16 p50 ms | 40.0 | 0.71 | 56.7× |
| search c=16 p99 ms | 94.8 | 1.52 | 62.2× |
| search c=64 req/s | 330 | 26,671 | 80.7× |
| search c=64 p50 ms | 186 | 2.27 | 81.9× |
| search c=64 p99 ms | 260 | 4.54 | 57.4× |
| avatar c=1 req/s | 18,156 | 39,126 | 2.2× |
| avatar c=1 p50 ms | 0.05 | 0.02 | 2.1× |
| avatar c=1 p99 ms | 0.12 | 0.03 | 3.7× |
| avatar c=16 req/s | 60,549 | 195,204 | 3.2× |
| avatar c=16 p50 ms | 0.17 | 0.07 | 2.5× |
| avatar c=16 p99 ms | 1.35 | 0.25 | 5.4× |
| avatar c=64 req/s | 51,209 | 201,335 | 3.9× |
| avatar c=64 p50 ms | 0.47 | 0.27 | 1.7× |
| avatar c=64 p99 ms | 7.73 | 1.73 | 4.5× |
| static_css c=1 req/s | 22,780 | 41,488 | 1.8× |
| static_css c=1 p50 ms | 0.04 | 0.02 | 1.8× |
| static_css c=1 p99 ms | 0.09 | 0.03 | 3.0× |
| static_css c=16 req/s | 83,625 | 209,257 | 2.5× |
| static_css c=16 p50 ms | 0.13 | 0.07 | 2.0× |
| static_css c=16 p99 ms | 0.99 | 0.23 | 4.3× |
| static_css c=64 req/s | 72,510 | 213,897 | 2.9× |
| static_css c=64 p50 ms | 0.42 | 0.27 | 1.6× |
| static_css c=64 p99 ms | 5.11 | 1.54 | 3.3× |
| up c=1 req/s | 1,535 | 23,842 | 15.5× |
| up c=1 p50 ms | 0.59 | 0.04 | 14.7× |
| up c=1 p99 ms | 1.25 | 0.06 | 21.9× |
| up c=16 req/s | 3,474 | 120,668 | 34.7× |
| up c=16 p50 ms | 4.47 | 0.13 | 33.9× |
| up c=16 p99 ms | 8.81 | 0.23 | 38.3× |
| up c=64 req/s | 3,380 | 122,115 | 36.1× |
| up c=64 p50 ms | 18.5 | 0.51 | 36.5× |
| up c=64 p99 ms | 31.9 | 1.07 | 29.6× |
| post_message c=1 req/s | 103 | 2,020 | 19.6× |
| post_message c=1 p50 ms | 8.09 | 0.44 | 18.3× |
| post_message c=1 p99 ms | 37.1 | 0.72 | 51.3× |
| post_message c=16 req/s | 183 | 4,142 | 22.6× |
| post_message c=16 p50 ms | 78.4 | 2.92 | 26.8× |
| post_message c=16 p99 ms | 215 | 36.6 | 5.9× |
| post_message c=64 req/s | 198 | 4,093 | 20.7× |
| post_message c=64 p50 ms | 315 | 12.0 | 26.3× |
| post_message c=64 p99 ms | 465 | 49.9 | 9.3× |

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
| 100 clients: paced post→one client p50 ms | 13.8 | 1.60 | 8.6× |
| 100 clients: paced post→all clients p50 ms | 19.0 | 1.86 | 10.2× |
| 100 clients: paced post→all clients p99 ms | 62.4 | 2.55 | 24.5× |
| 100 clients: max sustained msgs/s (delivered to all) | 73.8 | 2,354 | 31.9× |
| 100 clients: deliveries/s (client×message) | 7,382 | 235,432 | 31.9× |
| 100 clients: saturated post→all p50 ms | 57.6 | 1.97 | 29.3× |
| 100 clients: saturated POST p50 ms | 44.7 | 1.49 | 30.0× |
| 500 clients: subscribed | 500 | 500 | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.88 | 0.12 | 7.3× |
| 500 clients: paced post→one client p50 ms | 26.8 | 2.71 | 9.9× |
| 500 clients: paced post→all clients p50 ms | 50.9 | 4.20 | 12.1× |
| 500 clients: paced post→all clients p99 ms | 113 | 7.05 | 16.0× |
| 500 clients: max sustained msgs/s (delivered to all) | 21.8 | 708 | 32.5× |
| 500 clients: deliveries/s (client×message) | 10,882 | 353,904 | 32.5× |
| 500 clients: saturated post→all p50 ms | 142 | 11.8 | 12.0× |
| 500 clients: saturated POST p50 ms | 183 | 5.26 | 34.7× |
| 1000 clients: subscribed | 1,000 | 1,000 | 1.0× |
| 1000 clients: connect+subscribe all (s) | 1.66 | 0.18 | 9.2× |
| 1000 clients: paced post→one client p50 ms | 46.4 | 4.39 | 10.5× |
| 1000 clients: paced post→all clients p50 ms | 100 | 7.33 | 13.6× |
| 1000 clients: paced post→all clients p99 ms | 163 | 19.2 | 8.5× |
| 1000 clients: max sustained msgs/s (delivered to all) | 10.7 | 375 | 35.1× |
| 1000 clients: deliveries/s (client×message) | 10,712 | 375,142 | 35.0× |
| 1000 clients: saturated post→all p50 ms | 2,075 | 23.1 | 89.9× |
| 1000 clients: saturated POST p50 ms | 152 | 10.3 | 14.8× |

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
| 100 clients, all subscribed, idle: app process Pss | 569 | 120 | 4.7× |
| 100 clients, all subscribed, idle: app process RssAnon | 717 | 98.5 | 7.3× |
| 100 clients, all subscribed, idle: app + Redis + Thruster Pss | 606 | 120 | 5.0× |
| 100 clients, all subscribed, idle: whole container Pss | 873 | 120 | 7.2× |
| 100 clients, saturated fan-out: app process Pss | 677 | 120 | 5.6× |
| 100 clients, saturated fan-out: app process RssAnon | 823 | 98.5 | 8.4× |
| 100 clients, saturated fan-out: app + Redis + Thruster Pss | 725 | 120 | 6.0× |
| 100 clients, saturated fan-out: whole container Pss | 992 | 120 | 8.2× |
| 500 clients, all subscribed, idle: app process Pss | 625 | 121 | 5.2× |
| 500 clients, all subscribed, idle: app process RssAnon | 771 | 98.8 | 7.8× |
| 500 clients, all subscribed, idle: app + Redis + Thruster Pss | 692 | 121 | 5.7× |
| 500 clients, all subscribed, idle: whole container Pss | 960 | 121 | 8.0× |
| 500 clients, saturated fan-out: app process Pss | 808 | 120 | 6.7× |
| 500 clients, saturated fan-out: app process RssAnon | 953 | 98.0 | 9.7× |
| 500 clients, saturated fan-out: app + Redis + Thruster Pss | 884 | 120 | 7.4× |
| 500 clients, saturated fan-out: whole container Pss | 1,152 | 120 | 9.6× |
| 1000 clients, all subscribed, idle: app process Pss | 684 | 123 | 5.6× |
| 1000 clients, all subscribed, idle: app process RssAnon | 829 | 101 | 8.2× |
| 1000 clients, all subscribed, idle: app + Redis + Thruster Pss | 780 | 123 | 6.3× |
| 1000 clients, all subscribed, idle: whole container Pss | 1,047 | 123 | 8.5× |
| 1000 clients, saturated fan-out: app process Pss | 1,004 | 123 | 8.2× |
| 1000 clients, saturated fan-out: app process RssAnon | 1,149 | 101 | 11.4× |
| 1000 clients, saturated fan-out: app + Redis + Thruster Pss | 1,111 | 123 | 9.0× |
| 1000 clients, saturated fan-out: whole container Pss | 1,376 | 123 | 11.2× |
