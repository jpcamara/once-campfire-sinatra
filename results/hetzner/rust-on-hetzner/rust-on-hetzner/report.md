```
date: 2026-10-07T16:32:41+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
reference image: campfire-reference:app sha256:0701d9b06ec642db9cdac8efc2854ba0e7f33d404af39d814acbc0d56323f6b0 2026-10-05T17:10:33.410393286+02:00
rails-opt image: campfire-reference:rails-opt sha256:6f520516328aa2a27175662c32aed1c8c7d432e7b5e8b0ec8f578edfc542ec3b 2026-10-07T15:03:20.686141338+02:00
sinatra image: campfire-sinatra:app sha256:5a4251f6788448a44bb213f11a821a7e17b219fbb024004e2d09208918118726 2026-10-07T15:02:52.186225614+02:00
rage image: campfire-rage:app sha256:9a8fa62006cb18e3ccb9fc55ed3a093f48a6794b041ae9303d4ce31c0c7e0af9 2026-10-07T15:02:58.993474214+02:00
rust image: campfire-rust:app sha256:ecb3890f2706b5cec162be650e18c22d15d1627382bdba574c36a123975fab8b 2026-10-07T16:29:31.789282932+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: reference 3, rust 3. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| cold start: docker run → /up 200 (ms) | 3,648 [3,586–3,665] | 262 [254–275] | 13.9× |
| idle memory.current (MB) | 301 [298–305] | 15.0 [15.0–15.0] | 20.1× |
| idle anon (MB) | 282 [279–286] | 13.0 [13.0–13.0] | 21.7× |
| peak memory.current under load (MB) | 1,564 [1,448–1,573] | 362 [356–365] | 4.3× |
| peak anon under load (MB) | 1,456 [1,346–1,470] | 265 [258–266] | 5.5× |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| room_show c=1 req/s | 92.4 [88.9–92.9] | 5,450 [5,444–5,511] | 59.0× |
| room_show c=1 p50 ms | 10.4 [10.2–10.5] | 0.18 [0.18–0.18] | 57.9× |
| room_show c=1 p99 ms | 13.2 [12.6–22.9] | 0.27 [0.26–0.27] | 49.7× |
| room_show c=16 req/s | 225 [220–229] | 21,229 [21,129–21,325] | 94.4× |
| room_show c=16 p50 ms | 68.4 [45.4–72.0] | 0.73 [0.73–0.74] | 93.5× |
| room_show c=16 p99 ms | 163 [147–178] | 1.33 [1.32–1.33] | 122.9× |
| room_show c=64 req/s | 213 [185–216] | 21,788 [21,767–21,953] | 102.3× |
| room_show c=64 p50 ms | 293 [257–293] | 2.87 [2.85–2.87] | 102.1× |
| room_show c=64 p99 ms | 397 [371–615] | 5.13 [5.11–5.17] | 77.4× |
| messages_page c=1 req/s | 165 [161–167] | 6,075 [6,024–6,087] | 36.8× |
| messages_page c=1 p50 ms | 5.95 [5.90–6.07] | 0.16 [0.16–0.16] | 36.7× |
| messages_page c=1 p99 ms | 7.48 [7.29–7.64] | 0.23 [0.23–0.23] | 32.1× |
| messages_page c=16 req/s | 360 [358–372] | 23,565 [23,469–23,677] | 65.4× |
| messages_page c=16 p50 ms | 41.9 [41.7–45.2] | 0.66 [0.66–0.66] | 63.2× |
| messages_page c=16 p99 ms | 94.6 [89.2–103.6] | 1.13 [1.13–1.16] | 83.6× |
| messages_page c=64 req/s | 351 [333–358] | 24,278 [24,183–24,538] | 69.2× |
| messages_page c=64 p50 ms | 182 [177–185] | 2.58 [2.56–2.59] | 70.6× |
| messages_page c=64 p99 ms | 253 [218–270] | 4.43 [4.40–4.50] | 57.1× |
| sidebar c=1 req/s | 206 [193–208] | 5,161 [5,148–5,166] | 25.1× |
| sidebar c=1 p50 ms | 4.72 [4.67–5.02] | 0.19 [0.19–0.19] | 24.9× |
| sidebar c=1 p99 ms | 6.59 [6.39–6.79] | 0.28 [0.28–0.29] | 23.3× |
| sidebar c=16 req/s | 480 [464–488] | 20,828 [20,816–20,869] | 43.4× |
| sidebar c=16 p50 ms | 32.7 [30.8–33.8] | 0.74 [0.74–0.74] | 44.0× |
| sidebar c=16 p99 ms | 60.4 [58.4–62.0] | 1.39 [1.39–1.40] | 43.4× |
| sidebar c=64 req/s | 479 [405–488] | 21,492 [21,466–21,577] | 44.9× |
| sidebar c=64 p50 ms | 138 [126–143] | 2.90 [2.88–2.90] | 47.5× |
| sidebar c=64 p99 ms | 183 [169–232] | 5.46 [5.42–5.47] | 33.6× |
| search c=1 req/s | 164 [158–165] | 5,854 [5,848–5,890] | 35.6× |
| search c=1 p50 ms | 5.98 [5.97–6.23] | 0.17 [0.17–0.17] | 35.4× |
| search c=1 p99 ms | 7.71 [7.69–7.98] | 0.23 [0.22–0.23] | 33.8× |
| search c=16 req/s | 382 [366–383] | 21,276 [21,182–21,290] | 55.8× |
| search c=16 p50 ms | 39.6 [37.8–41.0] | 0.70 [0.70–0.71] | 56.1× |
| search c=16 p99 ms | 90.0 [88.1–90.9] | 1.52 [1.52–1.53] | 59.2× |
| search c=64 req/s | 371 [325–376] | 26,800 [26,159–26,846] | 72.2× |
| search c=64 p50 ms | 171 [161–187] | 2.26 [2.26–2.31] | 75.5× |
| search c=64 p99 ms | 252 [213–287] | 4.59 [4.51–4.75] | 54.8× |
| avatar c=1 req/s | 18,057 [17,855–18,142] | 39,301 [39,113–39,838] | 2.2× |
| avatar c=1 p50 ms | 0.05 [0.05–0.05] | 0.02 [0.02–0.02] | 2.1× |
| avatar c=1 p99 ms | 0.12 [0.12–0.12] | 0.03 [0.03–0.03] | 3.7× |
| avatar c=16 req/s | 61,687 [61,431–62,234] | 196,297 [195,745–197,762] | 3.2× |
| avatar c=16 p50 ms | 0.17 [0.17–0.17] | 0.07 [0.07–0.07] | 2.4× |
| avatar c=16 p99 ms | 1.34 [1.30–1.34] | 0.24 [0.24–0.25] | 5.5× |
| avatar c=64 req/s | 51,138 [50,715–51,874] | 200,722 [199,599–201,713] | 3.9× |
| avatar c=64 p50 ms | 0.49 [0.46–0.51] | 0.28 [0.27–0.28] | 1.8× |
| avatar c=64 p99 ms | 7.63 [7.42–7.68] | 1.69 [1.65–1.75] | 4.5× |
| static_css c=1 req/s | 23,053 [22,839–23,601] | 42,344 [41,680–42,394] | 1.8× |
| static_css c=1 p50 ms | 0.04 [0.04–0.04] | 0.02 [0.02–0.02] | 1.9× |
| static_css c=1 p99 ms | 0.09 [0.09–0.09] | 0.03 [0.03–0.03] | 2.9× |
| static_css c=16 req/s | 82,851 [82,545–84,397] | 211,051 [209,787–211,930] | 2.5× |
| static_css c=16 p50 ms | 0.13 [0.13–0.14] | 0.07 [0.07–0.07] | 2.1× |
| static_css c=16 p99 ms | 0.99 [0.96–1.04] | 0.22 [0.22–0.23] | 4.5× |
| static_css c=64 req/s | 71,927 [71,825–72,535] | 214,031 [212,875–215,608] | 3.0× |
| static_css c=64 p50 ms | 0.43 [0.42–0.45] | 0.26 [0.26–0.26] | 1.7× |
| static_css c=64 p99 ms | 5.13 [5.09–5.24] | 1.73 [1.62–1.73] | 3.0× |
| up c=1 req/s | 1,546 [1,534–1,570] | 24,176 [23,981–24,375] | 15.6× |
| up c=1 p50 ms | 0.58 [0.57–0.59] | 0.04 [0.04–0.04] | 14.9× |
| up c=1 p99 ms | 1.14 [1.13–1.24] | 0.06 [0.06–0.06] | 19.7× |
| up c=16 req/s | 3,463 [3,436–3,515] | 117,588 [117,297–118,609] | 34.0× |
| up c=16 p50 ms | 4.44 [4.42–4.53] | 0.13 [0.13–0.13] | 33.2× |
| up c=16 p99 ms | 8.86 [8.81–9.60] | 0.24 [0.24–0.24] | 36.5× |
| up c=64 req/s | 3,469 [3,318–3,506] | 125,096 [123,009–126,429] | 36.1× |
| up c=64 p50 ms | 18.3 [18.2–18.8] | 0.49 [0.49–0.50] | 37.2× |
| up c=64 p99 ms | 27.0 [26.3–34.8] | 1.05 [1.03–1.06] | 25.6× |
| post_message c=1 req/s | 113 [92–114] | 2,053 [1,985–2,066] | 18.2× |
| post_message c=1 p50 ms | 7.97 [7.93–8.26] | 0.44 [0.43–0.44] | 18.3× |
| post_message c=1 p99 ms | 31.6 [30.1–35.7] | 0.72 [0.68–0.80] | 43.7× |
| post_message c=16 req/s | 198 [196–201] | 4,153 [4,080–4,196] | 20.9× |
| post_message c=16 p50 ms | 71.6 [58.1–72.7] | 2.90 [2.90–2.91] | 24.7× |
| post_message c=16 p99 ms | 202 [195–245] | 37.0 [36.4–38.6] | 5.4× |
| post_message c=64 req/s | 195 [195–200] | 4,090 [4,050–4,098] | 20.9× |
| post_message c=64 p50 ms | 321 [299–322] | 11.9 [11.8–11.9] | 27.0× |
| post_message c=64 p99 ms | 461 [455–513] | 51.5 [49.6–52.4] | 9.0× |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
- reference: none
- rust: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| 100 clients: subscribed | 100 [100–100] | 100 [100–100] | 1.0× |
| 100 clients: connect+subscribe all (s) | 0.28 [0.28–0.29] | 0.06 [0.06–0.08] | 4.7× |
| 100 clients: paced post→one client p50 ms | 14.2 [13.6–14.4] | 1.72 [1.66–1.80] | 8.2× |
| 100 clients: paced post→all clients p50 ms | 19.5 [18.2–20.0] | 2.06 [2.05–2.16] | 9.5× |
| 100 clients: paced post→all clients p99 ms | 63.9 [37.6–65.7] | 11.7 [2.5–19.6] | 5.4× |
| 100 clients: max sustained msgs/s (delivered to all) | 74.7 [73.7–75.1] | 2,302 [2,292–2,331] | 30.8× |
| 100 clients: deliveries/s (client×message) | 7,466 [7,368–7,506] | 230,164 [229,251–233,106] | 30.8× |
| 100 clients: saturated post→all p50 ms | 57.9 [55.2–58.6] | 1.96 [1.95–1.99] | 29.5× |
| 100 clients: saturated POST p50 ms | 46.2 [42.1–47.8] | 1.49 [1.47–1.50] | 31.0× |
| 500 clients: subscribed | 500 [500–500] | 500 [500–500] | 1.0× |
| 500 clients: connect+subscribe all (s) | 0.92 [0.92–0.97] | 0.12 [0.12–0.14] | 7.7× |
| 500 clients: paced post→one client p50 ms | 26.0 [25.5–28.2] | 2.71 [2.54–2.90] | 9.6× |
| 500 clients: paced post→all clients p50 ms | 54.8 [49.9–57.5] | 3.92 [3.78–4.76] | 14.0× |
| 500 clients: paced post→all clients p99 ms | 78.5 [72.0–105.0] | 11.3 [6.5–13.3] | 6.9× |
| 500 clients: max sustained msgs/s (delivered to all) | 21.8 [19.7–22.9] | 716 [713–718] | 32.8× |
| 500 clients: deliveries/s (client×message) | 10,923 [9,826–11,448] | 357,946 [356,651–359,146] | 32.8× |
| 500 clients: saturated post→all p50 ms | 168 [139–324] | 11.7 [11.7–11.7] | 14.4× |
| 500 clients: saturated POST p50 ms | 149 [120–167] | 5.19 [5.16–5.21] | 28.7× |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | 1,000 [1,000–1,000] | 1.0× |
| 1000 clients: connect+subscribe all (s) | 1.66 [1.63–2.05] | 0.21 [0.20–0.22] | 7.9× |
| 1000 clients: paced post→one client p50 ms | 44.6 [43.0–45.9] | 4.25 [4.17–4.35] | 10.5× |
| 1000 clients: paced post→all clients p50 ms | 97.0 [91.7–106.2] | 7.19 [6.99–7.97] | 13.5× |
| 1000 clients: paced post→all clients p99 ms | 173 [162–203] | 11.2 [11.2–11.3] | 15.5× |
| 1000 clients: max sustained msgs/s (delivered to all) | 11.2 [10.6–11.7] | 378 [378–381] | 33.8× |
| 1000 clients: deliveries/s (client×message) | 11,165 [10,628–11,716] | 378,301 [377,600–381,378] | 33.9× |
| 1000 clients: saturated post→all p50 ms | 317 [294–1,687] | 22.9 [22.8–23.1] | 13.9× |
| 1000 clients: saturated POST p50 ms | 275 [238–299] | 10.2 [10.1–10.4] | 26.9× |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| POST with attachment (ms) | 71.3 [68.7–98.2] | 34.0 [33.3–34.6] | 2.1× |
| then GET thumb → 200 (ms) | 0.50 [0.40–0.50] | 0.30 [0.30–0.40] | 1.7× |
| POST → thumbnail served (ms) | 71.6 [69.2–98.6] | 34.3 [33.7–34.9] | 2.1× |

### Memory during cable fan-out, by process (MB, peak within the phase)

App process: Rails' Puma master and workers (Action Cable runs in them), or Rust's one campfire
process (its front server included). Pss counts pages shared between forked workers once;
RssAnon counts them in every process.

| Metric | Rails | Rust | Rust adv. |
|---|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 558 [552–568] | 122 [120–122] | 4.6× |
| 100 clients, all subscribed, idle: app process RssAnon | 706 [696–714] | 99.6 [98.6–99.8] | 7.1× |
| 100 clients, all subscribed, idle: app + Redis + Thruster Pss | 594 [588–604] | 122 [120–122] | 4.9× |
| 100 clients, all subscribed, idle: whole container Pss | 862 [857–871] | 122 [120–122] | 7.1× |
| 100 clients, saturated fan-out: app process Pss | 672 [651–685] | 122 [120–122] | 5.5× |
| 100 clients, saturated fan-out: app process RssAnon | 819 [794–827] | 99.6 [98.6–99.8] | 8.2× |
| 100 clients, saturated fan-out: app + Redis + Thruster Pss | 720 [698–733] | 122 [120–122] | 5.9× |
| 100 clients, saturated fan-out: whole container Pss | 989 [968–1,001] | 122 [120–122] | 8.1× |
| 500 clients, all subscribed, idle: app process Pss | 621 [621–632] | 114 [112–117] | 5.4× |
| 500 clients, all subscribed, idle: app process RssAnon | 762 [762–779] | 92.1 [90.4–95.0] | 8.3× |
| 500 clients, all subscribed, idle: app + Redis + Thruster Pss | 686 [686–698] | 114 [112–117] | 6.0× |
| 500 clients, all subscribed, idle: whole container Pss | 957 [954–966] | 114 [112–117] | 8.4× |
| 500 clients, saturated fan-out: app process Pss | 776 [725–813] | 113 [113–117] | 6.9× |
| 500 clients, saturated fan-out: app process RssAnon | 922 [866–954] | 91.2 [90.6–95.3] | 10.1× |
| 500 clients, saturated fan-out: app + Redis + Thruster Pss | 849 [798–886] | 113 [113–117] | 7.5× |
| 500 clients, saturated fan-out: whole container Pss | 1,116 [1,066–1,153] | 113 [113–117] | 9.9× |
| 1000 clients, all subscribed, idle: app process Pss | 670 [647–696] | 118 [116–123] | 5.7× |
| 1000 clients, all subscribed, idle: app process RssAnon | 816 [788–836] | 96.3 [93.9–100.7] | 8.5× |
| 1000 clients, all subscribed, idle: app + Redis + Thruster Pss | 797 [776–820] | 118 [116–123] | 6.7× |
| 1000 clients, all subscribed, idle: whole container Pss | 1,066 [1,047–1,089] | 118 [116–123] | 9.0× |
| 1000 clients, saturated fan-out: app process Pss | 1,019 [900–1,024] | 118 [116–122] | 8.6× |
| 1000 clients, saturated fan-out: app process RssAnon | 1,159 [1,039–1,169] | 96.0 [94.3–100.5] | 12.1× |
| 1000 clients, saturated fan-out: app + Redis + Thruster Pss | 1,153 [1,029–1,155] | 118 [116–122] | 9.8× |
| 1000 clients, saturated fan-out: whole container Pss | 1,420 [1,295–1,421] | 118 [116–122] | 12.0× |
