```
date: 2026-10-08T01:25:40+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
reference image: campfire-reference:app sha256:0701d9b06ec642db9cdac8efc2854ba0e7f33d404af39d814acbc0d56323f6b0 2026-10-05T17:10:33.410393286+02:00
rails-opt image: campfire-reference:rails-opt sha256:b7dbb13afbe430c2229705cbef98a4a0ba17705d77f8a530c49d07626b46f670 2026-10-08T00:28:30.899881926+02:00
sinatra image: campfire-sinatra:app sha256:4f4bbaf837cfc27c84131a57a6bc531a17e55d359d3c135b487c61e98ab5892c 2026-10-08T00:02:42.862560516+02:00
rage image: campfire-rage:app sha256:fec54a77a520a3121a8a5d20c4b2a4feadc6476a7119a55a0276551fce3fa5d8 2026-10-08T00:13:15.796284949+02:00
rust image: campfire-rust:app sha256:ecb3890f2706b5cec162be650e18c22d15d1627382bdba574c36a123975fab8b 2026-10-07T16:29:31.789282932+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: reference 1, rust 1. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 3,676 | 280 | 13.1× |
| idle memory.current (MB) | 305 | 15.0 | 20.3× |
| idle anon (MB) | 285 | 13.0 | 21.9× |
| peak memory.current under load (MB) | 1,379 | 238 | 5.8× |
| peak anon under load (MB) | 1,271 | 101 | 12.6× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| room_show c=1 req/s | 92.8 | 5,449 | 58.7× |
| room_show c=1 p50 ms | 10.4 | 0.18 | 58.0× |
| room_show c=1 p99 ms | 14.9 | 0.26 | 56.9× |
| room_show c=16 req/s | 228 | 21,024 | 92.4× |
| room_show c=16 p50 ms | 43.5 | 0.74 | 59.1× |
| room_show c=16 p99 ms | 196 | 1.35 | 145.3× |
| room_show c=64 req/s | 217 | 21,910 | 100.9× |
| room_show c=64 p50 ms | 298 | 2.85 | 104.6× |
| room_show c=64 p99 ms | 402 | 5.14 | 78.2× |
| messages_page c=1 req/s | 164 | 6,076 | 37.0× |
| messages_page c=1 p50 ms | 5.98 | 0.16 | 36.9× |
| messages_page c=1 p99 ms | 7.49 | 0.22 | 33.4× |
| messages_page c=16 req/s | 353 | 23,720 | 67.1× |
| messages_page c=16 p50 ms | 43.7 | 0.66 | 66.4× |
| messages_page c=16 p99 ms | 83.3 | 1.13 | 73.7× |
| messages_page c=64 req/s | 352 | 24,396 | 69.2× |
| messages_page c=64 p50 ms | 187 | 2.57 | 72.7× |
| messages_page c=64 p99 ms | 229 | 4.39 | 52.2× |
| sidebar c=1 req/s | 208 | 5,160 | 24.8× |
| sidebar c=1 p50 ms | 4.70 | 0.19 | 24.8× |
| sidebar c=1 p99 ms | 6.38 | 0.28 | 22.4× |
| sidebar c=16 req/s | 482 | 20,769 | 43.1× |
| sidebar c=16 p50 ms | 33.5 | 0.74 | 45.0× |
| sidebar c=16 p99 ms | 59.0 | 1.40 | 42.1× |
| sidebar c=64 req/s | 480 | 21,233 | 44.2× |
| sidebar c=64 p50 ms | 134 | 2.92 | 46.0× |
| sidebar c=64 p99 ms | 182 | 5.67 | 32.2× |
| search c=1 req/s | 165 | 5,865 | 35.5× |
| search c=1 p50 ms | 5.96 | 0.17 | 35.4× |
| search c=1 p99 ms | 7.96 | 0.22 | 35.5× |
| search c=16 req/s | 381 | 21,361 | 56.0× |
| search c=16 p50 ms | 36.3 | 0.70 | 51.6× |
| search c=16 p99 ms | 91.4 | 1.52 | 60.0× |
| search c=64 req/s | 375 | 26,478 | 70.6× |
| search c=64 p50 ms | 169 | 2.29 | 74.0× |
| search c=64 p99 ms | 211 | 4.63 | 45.6× |
| avatar c=1 req/s | 17,776 | 38,370 | 2.2× |
| avatar c=1 p50 ms | 0.05 | 0.03 | 2.1× |
| avatar c=1 p99 ms | 0.12 | 0.03 | 3.7× |
| avatar c=16 req/s | 62,733 | 196,801 | 3.1× |
| avatar c=16 p50 ms | 0.17 | 0.07 | 2.4× |
| avatar c=16 p99 ms | 1.30 | 0.25 | 5.2× |
| avatar c=64 req/s | 50,674 | 200,459 | 4.0× |
| avatar c=64 p50 ms | 0.46 | 0.28 | 1.7× |
| avatar c=64 p99 ms | 7.88 | 1.69 | 4.7× |
| static_css c=1 req/s | 23,756 | 41,648 | 1.8× |
| static_css c=1 p50 ms | 0.04 | 0.02 | 1.8× |
| static_css c=1 p99 ms | 0.09 | 0.03 | 2.7× |
| static_css c=16 req/s | 84,556 | 208,506 | 2.5× |
| static_css c=16 p50 ms | 0.13 | 0.07 | 2.0× |
| static_css c=16 p99 ms | 0.97 | 0.23 | 4.2× |
| static_css c=64 req/s | 72,619 | 210,847 | 2.9× |
| static_css c=64 p50 ms | 0.42 | 0.27 | 1.6× |
| static_css c=64 p99 ms | 5.07 | 1.33 | 3.8× |
| up c=1 req/s | 1,536 | 23,742 | 15.5× |
| up c=1 p50 ms | 0.59 | 0.04 | 14.7× |
| up c=1 p99 ms | 1.19 | 0.06 | 20.9× |
| up c=16 req/s | 3,408 | 118,329 | 34.7× |
| up c=16 p50 ms | 4.51 | 0.13 | 33.7× |
| up c=16 p99 ms | 9.41 | 0.24 | 39.5× |
| up c=64 req/s | 3,445 | 123,398 | 35.8× |
| up c=64 p50 ms | 18.4 | 0.50 | 36.8× |
| up c=64 p99 ms | 27.9 | 1.05 | 26.5× |
| post_message c=1 req/s | 115 | 1,996 | 17.4× |
| post_message c=1 p50 ms | 7.89 | 0.44 | 17.9× |
| post_message c=1 p99 ms | 28.9 | 0.73 | 39.5× |
| post_message c=16 req/s | 195 | 4,102 | 21.1× |
| post_message c=16 p50 ms | 71.2 | 2.93 | 24.3× |
| post_message c=16 p99 ms | 231 | 37.5 | 6.2× |
| post_message c=64 req/s | 196 | 3,986 | 20.3× |
| post_message c=64 p50 ms | 317 | 12.1 | 26.3× |
| post_message c=64 p99 ms | 478 | 51.0 | 9.4× |

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
| 100 clients: paced post→one client p50 ms | 13.7 | 1.57 | 8.7× |
| 100 clients: paced post→all clients p50 ms | 18.9 | 1.74 | 10.8× |
| 100 clients: paced post→all clients p99 ms | 73.6 | 2.70 | 27.2× |
| 100 clients: max sustained msgs/s (delivered to all) | 72.8 | 2,260 | 31.0× |
| 100 clients: deliveries/s (client×message) | 7,284 | 226,044 | 31.0× |
| 100 clients: saturated post→all p50 ms | 59.1 | 1.95 | 30.3× |
| 100 clients: saturated POST p50 ms | 44.8 | 1.50 | 29.9× |
| 500 clients: subscribed | 500 | 500 | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.92 | 0.17 | 5.4× |
| 500 clients: paced post→one client p50 ms | 28.2 | 2.88 | 9.8× |
| 500 clients: paced post→all clients p50 ms | 54.4 | 4.40 | 12.4× |
| 500 clients: paced post→all clients p99 ms | 103 | 8.38 | 12.2× |
| 500 clients: max sustained msgs/s (delivered to all) | 20.3 | 707 | 34.8× |
| 500 clients: deliveries/s (client×message) | 10,171 | 353,436 | 34.7× |
| 500 clients: saturated post→all p50 ms | 156 | 11.7 | 13.3× |
| 500 clients: saturated POST p50 ms | 191 | 5.20 | 36.8× |
| 1000 clients: subscribed | 1,000 | 1,000 | 1.0× |
| 1000 clients: connect+subscribe all (s) | 1.90 | 0.17 | 11.2× |
| 1000 clients: paced post→one client p50 ms | 44.1 | 4.82 | 9.2× |
| 1000 clients: paced post→all clients p50 ms | 90.6 | 8.56 | 10.6× |
| 1000 clients: paced post→all clients p99 ms | 213 | 11.7 | 18.2× |
| 1000 clients: max sustained msgs/s (delivered to all) | 12.0 | 376 | 31.3× |
| 1000 clients: deliveries/s (client×message) | 12,047 | 375,881 | 31.2× |
| 1000 clients: saturated post→all p50 ms | 252 | 23.0 | 11.0× |
| 1000 clients: saturated POST p50 ms | 269 | 10.2 | 26.4× |

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
| 100 clients, all subscribed, idle: app process Pss | 550 | 120 | 4.6× |
| 100 clients, all subscribed, idle: app process RssAnon | 697 | 98.4 | 7.1× |
| 100 clients, all subscribed, idle: app + Redis + Thruster Pss | 586 | 120 | 4.9× |
| 100 clients, all subscribed, idle: whole container Pss | 880 | 120 | 7.3× |
| 100 clients, saturated fan-out: app process Pss | 652 | 120 | 5.4× |
| 100 clients, saturated fan-out: app process RssAnon | 799 | 97.8 | 8.2× |
| 100 clients, saturated fan-out: app + Redis + Thruster Pss | 700 | 120 | 5.8× |
| 100 clients, saturated fan-out: whole container Pss | 996 | 120 | 8.3× |
| 500 clients, all subscribed, idle: app process Pss | 621 | 116 | 5.3× |
| 500 clients, all subscribed, idle: app process RssAnon | 767 | 94.4 | 8.1× |
| 500 clients, all subscribed, idle: app + Redis + Thruster Pss | 686 | 116 | 5.9× |
| 500 clients, all subscribed, idle: whole container Pss | 982 | 116 | 8.4× |
| 500 clients, saturated fan-out: app process Pss | 722 | 118 | 6.1× |
| 500 clients, saturated fan-out: app process RssAnon | 867 | 95.5 | 9.1× |
| 500 clients, saturated fan-out: app + Redis + Thruster Pss | 797 | 118 | 6.8× |
| 500 clients, saturated fan-out: whole container Pss | 1,091 | 118 | 9.3× |
| 1000 clients, all subscribed, idle: app process Pss | 652 | 124 | 5.3× |
| 1000 clients, all subscribed, idle: app process RssAnon | 797 | 102 | 7.9× |
| 1000 clients, all subscribed, idle: app + Redis + Thruster Pss | 789 | 124 | 6.4× |
| 1000 clients, all subscribed, idle: whole container Pss | 1,084 | 124 | 8.8× |
| 1000 clients, saturated fan-out: app process Pss | 893 | 124 | 7.2× |
| 1000 clients, saturated fan-out: app process RssAnon | 1,038 | 102 | 10.2× |
| 1000 clients, saturated fan-out: app + Redis + Thruster Pss | 1,034 | 124 | 8.4× |
| 1000 clients, saturated fan-out: whole container Pss | 1,326 | 124 | 10.7× |
