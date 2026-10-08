```
date: 2026-10-08T07:05:07+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
rage image: campfire-rage:app sha256:fec54a77a520a3121a8a5d20c4b2a4feadc6476a7119a55a0276551fce3fa5d8 2026-10-08T00:13:15.796284949+02:00
roda image: campfire-roda:app sha256:e1c9836cfb6fc66661f7a59cf899e6cec80d07c49e4d9e285b8d69de71eca2ee 2026-10-08T02:24:48.338647722+02:00
rust image: campfire-rust:app sha256:ecb3890f2706b5cec162be650e18c22d15d1627382bdba574c36a123975fab8b 2026-10-07T16:29:31.789282932+02:00
reference image: campfire-reference:app sha256:0701d9b06ec642db9cdac8efc2854ba0e7f33d404af39d814acbc0d56323f6b0 2026-10-05T17:10:33.410393286+02:00
sinatra image: campfire-sinatra:app sha256:4f4bbaf837cfc27c84131a57a6bc531a17e55d359d3c135b487c61e98ab5892c 2026-10-08T00:02:42.862560516+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: reference 1, rust 1. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 3,600 | 293 | 12.3× |
| idle memory.current (MB) | 302 | 15.0 | 20.1× |
| idle anon (MB) | 282 | 13.0 | 21.7× |
| peak memory.current under load (MB) | 1,546 | 366 | 4.2× |
| peak anon under load (MB) | 1,452 | 269 | 5.4× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| room_show c=1 req/s | 92.1 | 5,434 | 59.0× |
| room_show c=1 p50 ms | 10.5 | 0.18 | 58.4× |
| room_show c=1 p99 ms | 12.8 | 0.26 | 48.3× |
| room_show c=16 req/s | 222 | 21,029 | 94.9× |
| room_show c=16 p50 ms | 70.9 | 0.74 | 96.0× |
| room_show c=16 p99 ms | 130 | 1.33 | 97.7× |
| room_show c=64 req/s | 192 | 21,796 | 113.6× |
| room_show c=64 p50 ms | 347 | 2.87 | 120.8× |
| room_show c=64 p99 ms | 436 | 5.14 | 84.9× |
| messages_page c=1 req/s | 165 | 6,033 | 36.6× |
| messages_page c=1 p50 ms | 5.93 | 0.16 | 36.4× |
| messages_page c=1 p99 ms | 7.59 | 0.23 | 33.6× |
| messages_page c=16 req/s | 362 | 23,415 | 64.8× |
| messages_page c=16 p50 ms | 43.4 | 0.67 | 65.1× |
| messages_page c=16 p99 ms | 90.4 | 1.14 | 79.4× |
| messages_page c=64 req/s | 337 | 24,146 | 71.6× |
| messages_page c=64 p50 ms | 184 | 2.60 | 70.7× |
| messages_page c=64 p99 ms | 271 | 4.44 | 61.0× |
| sidebar c=1 req/s | 196 | 5,087 | 26.0× |
| sidebar c=1 p50 ms | 5.01 | 0.19 | 26.1× |
| sidebar c=1 p99 ms | 6.71 | 0.29 | 23.4× |
| sidebar c=16 req/s | 457 | 20,617 | 45.1× |
| sidebar c=16 p50 ms | 33.9 | 0.75 | 45.1× |
| sidebar c=16 p99 ms | 63.9 | 1.40 | 45.6× |
| sidebar c=64 req/s | 374 | 21,308 | 56.9× |
| sidebar c=64 p50 ms | 174 | 2.92 | 59.4× |
| sidebar c=64 p99 ms | 225 | 5.45 | 41.3× |
| search c=1 req/s | 152 | 5,773 | 37.9× |
| search c=1 p50 ms | 6.49 | 0.17 | 37.9× |
| search c=1 p99 ms | 7.90 | 0.23 | 34.5× |
| search c=16 req/s | 355 | 21,022 | 59.2× |
| search c=16 p50 ms | 45.8 | 0.71 | 64.3× |
| search c=16 p99 ms | 97.9 | 1.55 | 63.0× |
| search c=64 req/s | 311 | 26,467 | 85.1× |
| search c=64 p50 ms | 205 | 2.29 | 89.2× |
| search c=64 p99 ms | 285 | 4.54 | 62.8× |
| avatar c=1 req/s | 17,900 | 38,711 | 2.2× |
| avatar c=1 p50 ms | 0.05 | 0.02 | 2.2× |
| avatar c=1 p99 ms | 0.12 | 0.03 | 3.6× |
| avatar c=16 req/s | 62,236 | 196,960 | 3.2× |
| avatar c=16 p50 ms | 0.17 | 0.07 | 2.4× |
| avatar c=16 p99 ms | 1.29 | 0.24 | 5.4× |
| avatar c=64 req/s | 50,550 | 201,884 | 4.0× |
| avatar c=64 p50 ms | 0.47 | 0.27 | 1.7× |
| avatar c=64 p99 ms | 7.78 | 1.74 | 4.5× |
| static_css c=1 req/s | 22,996 | 41,978 | 1.8× |
| static_css c=1 p50 ms | 0.04 | 0.02 | 1.9× |
| static_css c=1 p99 ms | 0.09 | 0.03 | 2.9× |
| static_css c=16 req/s | 84,460 | 207,933 | 2.5× |
| static_css c=16 p50 ms | 0.13 | 0.07 | 2.0× |
| static_css c=16 p99 ms | 0.96 | 0.23 | 4.3× |
| static_css c=64 req/s | 70,752 | 209,164 | 3.0× |
| static_css c=64 p50 ms | 0.44 | 0.26 | 1.7× |
| static_css c=64 p99 ms | 5.35 | 1.78 | 3.0× |
| up c=1 req/s | 1,539 | 23,922 | 15.5× |
| up c=1 p50 ms | 0.58 | 0.04 | 14.9× |
| up c=1 p99 ms | 1.26 | 0.06 | 21.3× |
| up c=16 req/s | 3,450 | 120,560 | 34.9× |
| up c=16 p50 ms | 4.53 | 0.13 | 34.3× |
| up c=16 p99 ms | 8.62 | 0.23 | 37.3× |
| up c=64 req/s | 3,404 | 123,756 | 36.4× |
| up c=64 p50 ms | 18.7 | 0.50 | 37.4× |
| up c=64 p99 ms | 28.0 | 1.06 | 26.5× |
| post_message c=1 req/s | 98.9 | 1,992 | 20.1× |
| post_message c=1 p50 ms | 8.17 | 0.44 | 18.7× |
| post_message c=1 p99 ms | 33.4 | 0.79 | 42.4× |
| post_message c=16 req/s | 185 | 4,122 | 22.3× |
| post_message c=16 p50 ms | 79.9 | 2.90 | 27.6× |
| post_message c=16 p99 ms | 226 | 37.7 | 6.0× |
| post_message c=64 req/s | 199 | 4,068 | 20.5× |
| post_message c=64 p50 ms | 320 | 11.9 | 26.9× |
| post_message c=64 p99 ms | 459 | 50.0 | 9.2× |

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
| 100 clients: paced post→one client p50 ms | 14.0 | 1.73 | 8.1× |
| 100 clients: paced post→all clients p50 ms | 18.8 | 2.06 | 9.1× |
| 100 clients: paced post→all clients p99 ms | 66.4 | 2.76 | 24.1× |
| 100 clients: max sustained msgs/s (delivered to all) | 74.4 | 2,242 | 30.1× |
| 100 clients: deliveries/s (client×message) | 7,444 | 224,239 | 30.1× |
| 100 clients: saturated post→all p50 ms | 59.0 | 1.99 | 29.7× |
| 100 clients: saturated POST p50 ms | 47.8 | 1.51 | 31.7× |
| 500 clients: subscribed | 500 | 500 | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.89 | 0.13 | 6.8× |
| 500 clients: paced post→one client p50 ms | 25.7 | 2.96 | 8.7× |
| 500 clients: paced post→all clients p50 ms | 50.2 | 4.79 | 10.5× |
| 500 clients: paced post→all clients p99 ms | 115 | 8.55 | 13.4× |
| 500 clients: max sustained msgs/s (delivered to all) | 23.8 | 716 | 30.1× |
| 500 clients: deliveries/s (client×message) | 11,916 | 357,807 | 30.0× |
| 500 clients: saturated post→all p50 ms | 130 | 11.8 | 11.0× |
| 500 clients: saturated POST p50 ms | 128 | 5.17 | 24.7× |
| 1000 clients: subscribed | 1,000 | 1,000 | 1.0× |
| 1000 clients: connect+subscribe all (s) | 1.80 | 0.15 | 12.0× |
| 1000 clients: paced post→one client p50 ms | 40.4 | 4.05 | 10.0× |
| 1000 clients: paced post→all clients p50 ms | 87.0 | 7.18 | 12.1× |
| 1000 clients: paced post→all clients p99 ms | 170 | 18.7 | 9.1× |
| 1000 clients: max sustained msgs/s (delivered to all) | 12.4 | 382 | 30.8× |
| 1000 clients: deliveries/s (client×message) | 12,442 | 381,583 | 30.7× |
| 1000 clients: saturated post→all p50 ms | 266 | 23.3 | 11.4× |
| 1000 clients: saturated POST p50 ms | 293 | 10.1 | 29.1× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| POST with attachment (ms) | 86.3 | 34.6 | 2.5× |
| then GET thumb → 200 (ms) | 0.40 | 0.40 | 1.0× |
| POST → thumbnail served (ms) | 86.8 | 35.0 | 2.5× |

### Memory during cable fan-out, by process (MB, peak within the phase)

App process: Rails' Puma master and workers (Action Cable runs in them), or Rust's one campfire
process (its front server included). Pss counts pages shared between forked workers once;
RssAnon counts them in every process.

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 565 | 121 | 4.7× |
| 100 clients, all subscribed, idle: app process RssAnon | 713 | 99.2 | 7.2× |
| 100 clients, all subscribed, idle: app + Redis + Thruster Pss | 601 | 121 | 5.0× |
| 100 clients, all subscribed, idle: whole container Pss | 868 | 121 | 7.2× |
| 100 clients, saturated fan-out: app process Pss | 674 | 119 | 5.7× |
| 100 clients, saturated fan-out: app process RssAnon | 819 | 97.4 | 8.4× |
| 100 clients, saturated fan-out: app + Redis + Thruster Pss | 722 | 119 | 6.1× |
| 100 clients, saturated fan-out: whole container Pss | 989 | 119 | 8.3× |
| 500 clients, all subscribed, idle: app process Pss | 623 | 117 | 5.3× |
| 500 clients, all subscribed, idle: app process RssAnon | 766 | 95.0 | 8.1× |
| 500 clients, all subscribed, idle: app + Redis + Thruster Pss | 689 | 117 | 5.9× |
| 500 clients, all subscribed, idle: whole container Pss | 957 | 117 | 8.2× |
| 500 clients, saturated fan-out: app process Pss | 867 | 116 | 7.5× |
| 500 clients, saturated fan-out: app process RssAnon | 1,010 | 94.4 | 10.7× |
| 500 clients, saturated fan-out: app + Redis + Thruster Pss | 943 | 116 | 8.1× |
| 500 clients, saturated fan-out: whole container Pss | 1,207 | 116 | 10.4× |
| 1000 clients, all subscribed, idle: app process Pss | 698 | 124 | 5.6× |
| 1000 clients, all subscribed, idle: app process RssAnon | 841 | 102 | 8.2× |
| 1000 clients, all subscribed, idle: app + Redis + Thruster Pss | 829 | 124 | 6.7× |
| 1000 clients, all subscribed, idle: whole container Pss | 1,097 | 124 | 8.9× |
| 1000 clients, saturated fan-out: app process Pss | 1,027 | 124 | 8.3× |
| 1000 clients, saturated fan-out: app process RssAnon | 1,170 | 102 | 11.4× |
| 1000 clients, saturated fan-out: app + Redis + Thruster Pss | 1,164 | 124 | 9.4× |
| 1000 clients, saturated fan-out: whole container Pss | 1,429 | 124 | 11.5× |
