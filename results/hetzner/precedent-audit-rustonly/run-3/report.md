```
date: 2026-10-08T05:08:44+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
rage image: campfire-rage:app sha256:fec54a77a520a3121a8a5d20c4b2a4feadc6476a7119a55a0276551fce3fa5d8 2026-10-08T00:13:15.796284949+02:00
rails-opt image: campfire-reference:rails-opt sha256:b7dbb13afbe430c2229705cbef98a4a0ba17705d77f8a530c49d07626b46f670 2026-10-08T00:28:30.899881926+02:00
sinatra image: campfire-sinatra:app sha256:4f4bbaf837cfc27c84131a57a6bc531a17e55d359d3c135b487c61e98ab5892c 2026-10-08T00:02:42.862560516+02:00
rust HEAD:  (dirty: 0 files)
```

Reps: . Cells: median [min–max].

### Startup and memory

| Metric |  | Rust adv. |
|---|---|
| cold start: docker run → /up 200 (ms) |  | – |
| idle memory.current (MB) |  | – |
| idle anon (MB) |  | – |
| peak memory.current under load (MB) |  | – |
| peak anon under load (MB) |  | – |
