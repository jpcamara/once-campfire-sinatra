```
date: 2026-10-07T12:31:11+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
reference image: campfire-reference:app sha256:0701d9b06ec642db9cdac8efc2854ba0e7f33d404af39d814acbc0d56323f6b0 2026-10-05T17:10:33.410393286+02:00
rails-opt image: campfire-reference:rails-opt sha256:ce61e4b4af6d07c07ac1468fe6471ca8137681bc43c9be98c4c11c11a460f1bd 2026-10-07T04:18:55.638098636+02:00
sinatra image: campfire-sinatra:app sha256:31ca2dbf96fc420ac36aa1b7efbe5c3094bd5391c0f2b6cc7df98c08aa4bd87d 2026-10-07T11:35:29.222654926+02:00
rage image: campfire-rage:app sha256:4dcff5abb2d4a6ba1c823b88f7c6881298e6b0ad46c4c48a6e0ec0724aa068ee 2026-10-07T09:25:46.493556757+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: reference 3. Cells: median [min–max].

### Startup and memory

| Metric | Rails | Rust adv. |
|---|---|---|
| cold start: docker run → /up 200 (ms) | 3,573 [3,547–3,624] | – |
| idle memory.current (MB) | 303 [303–312] | – |
| idle anon (MB) | 284 [283–292] | – |
| peak memory.current under load (MB) | 1,500 [1,424–1,531] | – |
| peak anon under load (MB) | 1,398 [1,336–1,428] | – |

### HTTP (signed in as david; keep-alive; c = concurrent connections)

| Metric | Rails | Rust adv. |
|---|---|---|
| room_show c=1 req/s | 92.5 [92.5–93.6] | – |
| room_show c=1 p50 ms | 10.5 [10.4–10.6] | – |
| room_show c=1 p99 ms | 12.6 [12.5–12.9] | – |
| room_show c=16 req/s | 225 [222–230] | – |
| room_show c=16 p50 ms | 68.0 [27.6–70.5] | – |
| room_show c=16 p99 ms | 182 [172–251] | – |
| room_show c=64 req/s | 191 [186–213] | – |
| room_show c=64 p50 ms | 331 [307–337] | – |
| room_show c=64 p99 ms | 420 [389–457] | – |
| messages_page c=1 req/s | 164 [160–165] | – |
| messages_page c=1 p50 ms | 5.97 [5.96–6.10] | – |
| messages_page c=1 p99 ms | 7.54 [7.33–7.74] | – |
| messages_page c=16 req/s | 364 [362–376] | – |
| messages_page c=16 p50 ms | 43.3 [37.2–48.9] | – |
| messages_page c=16 p99 ms | 88.3 [86.0–124.5] | – |
| messages_page c=64 req/s | 327 [322–354] | – |
| messages_page c=64 p50 ms | 190 [179–195] | – |
| messages_page c=64 p99 ms | 260 [231–265] | – |
| sidebar c=1 req/s | 192 [186–208] | – |
| sidebar c=1 p50 ms | 5.00 [4.68–5.20] | – |
| sidebar c=1 p99 ms | 6.62 [6.40–15.54] | – |
| sidebar c=16 req/s | 482 [460–489] | – |
| sidebar c=16 p50 ms | 32.3 [26.6–34.6] | – |
| sidebar c=16 p99 ms | 70.8 [62.0–81.0] | – |
| sidebar c=64 req/s | 448 [404–475] | – |
| sidebar c=64 p50 ms | 140 [135–140] | – |
| sidebar c=64 p99 ms | 215 [214–248] | – |
| search c=1 req/s | 165 [155–165] | – |
| search c=1 p50 ms | 5.96 [5.94–6.38] | – |
| search c=1 p99 ms | 7.74 [7.58–8.04] | – |
| search c=16 req/s | 378 [372–384] | – |
| search c=16 p50 ms | 42.3 [39.7–43.5] | – |
| search c=16 p99 ms | 91.9 [84.5–92.5] | – |
| search c=64 req/s | 352 [329–371] | – |
| search c=64 p50 ms | 175 [160–186] | – |
| search c=64 p99 ms | 268 [256–290] | – |
| avatar c=1 req/s | 18,057 [18,047–18,364] | – |
| avatar c=1 p50 ms | 0.05 [0.05–0.05] | – |
| avatar c=1 p99 ms | 0.12 [0.12–0.12] | – |
| avatar c=16 req/s | 62,491 [62,132–62,686] | – |
| avatar c=16 p50 ms | 0.17 [0.17–0.17] | – |
| avatar c=16 p99 ms | 1.29 [1.28–1.29] | – |
| avatar c=64 req/s | 50,840 [50,774–51,221] | – |
| avatar c=64 p50 ms | 0.46 [0.46–0.46] | – |
| avatar c=64 p99 ms | 7.75 [7.70–7.88] | – |
| static_css c=1 req/s | 23,265 [22,512–23,870] | – |
| static_css c=1 p50 ms | 0.04 [0.04–0.04] | – |
| static_css c=1 p99 ms | 0.09 [0.09–0.09] | – |
| static_css c=16 req/s | 82,501 [81,754–85,429] | – |
| static_css c=16 p50 ms | 0.14 [0.13–0.14] | – |
| static_css c=16 p99 ms | 1.00 [0.93–1.03] | – |
| static_css c=64 req/s | 71,596 [71,456–73,706] | – |
| static_css c=64 p50 ms | 0.44 [0.42–0.45] | – |
| static_css c=64 p99 ms | 5.13 [5.02–5.28] | – |
| up c=1 req/s | 1,529 [1,529–1,552] | – |
| up c=1 p50 ms | 0.58 [0.58–0.58] | – |
| up c=1 p99 ms | 1.21 [1.18–1.76] | – |
| up c=16 req/s | 3,467 [3,454–3,486] | – |
| up c=16 p50 ms | 4.47 [4.47–4.51] | – |
| up c=16 p99 ms | 8.94 [8.78–9.08] | – |
| up c=64 req/s | 3,434 [3,403–3,447] | – |
| up c=64 p50 ms | 18.5 [18.5–18.7] | – |
| up c=64 p99 ms | 29.1 [27.1–29.1] | – |
| post_message c=1 req/s | 118 [94–119] | – |
| post_message c=1 p50 ms | 7.66 [7.64–8.35] | – |
| post_message c=1 p99 ms | 28.2 [27.6–35.7] | – |
| post_message c=16 req/s | 198 [197–200] | – |
| post_message c=16 p50 ms | 59.9 [59.0–74.0] | – |
| post_message c=16 p99 ms | 240 [193–262] | – |
| post_message c=64 req/s | 194 [193–201] | – |
| post_message c=64 p50 ms | 318 [311–325] | – |
| post_message c=64 p99 ms | 482 [480–484] | – |

### HTTP errors / non-2xx-3xx (first rep, per app)

| Metric | Rails | Rust adv. |
|---|---|---|
- reference: none

### Action Cable fan-out (one room; chatter.js subscriptions per client)

| Metric | Rails | Rust adv. |
|---|---|---|
| 100 clients: subscribed | 100 [100–100] | – |
| 100 clients: connect+subscribe all (s) | 0.32 [0.32–0.37] | – |
| 100 clients: paced post→one client p50 ms | 14.0 [13.2–14.3] | – |
| 100 clients: paced post→all clients p50 ms | 19.7 [19.5–20.5] | – |
| 100 clients: paced post→all clients p99 ms | 52.6 [50.3–60.9] | – |
| 100 clients: max sustained msgs/s (delivered to all) | 75.6 [75.2–76.7] | – |
| 100 clients: deliveries/s (client×message) | 7,558 [7,525–7,670] | – |
| 100 clients: saturated post→all p50 ms | 57.9 [57.0–60.1] | – |
| 100 clients: saturated POST p50 ms | 44.6 [44.1–45.8] | – |
| 500 clients: subscribed | 500 [500–500] | – |
| 500 clients: connect+subscribe all (s) | 0.87 [0.86–0.94] | – |
| 500 clients: paced post→one client p50 ms | 26.5 [25.5–28.0] | – |
| 500 clients: paced post→all clients p50 ms | 50.8 [50.0–58.2] | – |
| 500 clients: paced post→all clients p99 ms | 97.6 [91.7–113.2] | – |
| 500 clients: max sustained msgs/s (delivered to all) | 23.7 [20.2–23.8] | – |
| 500 clients: deliveries/s (client×message) | 11,874 [10,104–11,886] | – |
| 500 clients: saturated post→all p50 ms | 147 [138–688] | – |
| 500 clients: saturated POST p50 ms | 162 [122–163] | – |
| 1000 clients: subscribed | 1,000 [1,000–1,000] | – |
| 1000 clients: connect+subscribe all (s) | 1.91 [1.66–2.04] | – |
| 1000 clients: paced post→one client p50 ms | 42.8 [41.9–46.5] | – |
| 1000 clients: paced post→all clients p50 ms | 89.8 [88.6–165.8] | – |
| 1000 clients: paced post→all clients p99 ms | 194 [186–197] | – |
| 1000 clients: max sustained msgs/s (delivered to all) | 12.6 [11.4–12.7] | – |
| 1000 clients: deliveries/s (client×message) | 12,551 [11,396–12,697] | – |
| 1000 clients: saturated post→all p50 ms | 307 [290–1,626] | – |
| 1000 clients: saturated POST p50 ms | 242 [222–244] | – |

### Upload + thumbnail (black_hole.jpg, 505 KB)

| Metric | Rails | Rust adv. |
|---|---|---|
| POST with attachment (ms) | 66.4 [63.6–80.2] | – |
| then GET thumb → 200 (ms) | 0.50 [0.50–0.50] | – |
| POST → thumbnail served (ms) | 66.9 [64.1–80.6] | – |

### Memory during cable fan-out, by process (MB, peak within the phase)

App process: Rails' Puma master and workers (Action Cable runs in them), or Rust's one campfire
process (its front server included). Pss counts pages shared between forked workers once;
RssAnon counts them in every process.

| Metric | Rails | Rust adv. |
|---|---|---|
| 100 clients, all subscribed, idle: app process Pss | 561 [544–564] | – |
| 100 clients, all subscribed, idle: app process RssAnon | 707 [692–711] | – |
| 100 clients, all subscribed, idle: app + Redis + Thruster Pss | 597 [581–600] | – |
| 100 clients, all subscribed, idle: whole container Pss | 867 [855–869] | – |
| 100 clients, saturated fan-out: app process Pss | 690 [672–701] | – |
| 100 clients, saturated fan-out: app process RssAnon | 834 [818–844] | – |
| 100 clients, saturated fan-out: app + Redis + Thruster Pss | 738 [720–749] | – |
| 100 clients, saturated fan-out: whole container Pss | 1,007 [996–1,020] | – |
| 500 clients, all subscribed, idle: app process Pss | 636 [626–648] | – |
| 500 clients, all subscribed, idle: app process RssAnon | 781 [768–790] | – |
| 500 clients, all subscribed, idle: app + Redis + Thruster Pss | 699 [692–711] | – |
| 500 clients, all subscribed, idle: whole container Pss | 975 [960–980] | – |
| 500 clients, saturated fan-out: app process Pss | 842 [771–847] | – |
| 500 clients, saturated fan-out: app process RssAnon | 984 [916–990] | – |
| 500 clients, saturated fan-out: app + Redis + Thruster Pss | 916 [844–924] | – |
| 500 clients, saturated fan-out: whole container Pss | 1,185 [1,116–1,193] | – |
| 1000 clients, all subscribed, idle: app process Pss | 693 [672–703] | – |
| 1000 clients, all subscribed, idle: app process RssAnon | 835 [816–844] | – |
| 1000 clients, all subscribed, idle: app + Redis + Thruster Pss | 823 [783–826] | – |
| 1000 clients, all subscribed, idle: whole container Pss | 1,094 [1,059–1,097] | – |
| 1000 clients, saturated fan-out: app process Pss | 953 [906–997] | – |
| 1000 clients, saturated fan-out: app process RssAnon | 1,093 [1,050–1,138] | – |
| 1000 clients, saturated fan-out: app + Redis + Thruster Pss | 1,082 [1,024–1,132] | – |
| 1000 clients, saturated fan-out: whole container Pss | 1,350 [1,297–1,399] | – |
