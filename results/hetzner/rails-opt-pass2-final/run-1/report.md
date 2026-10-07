```
date: 2026-10-06T19:30:02+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
falcon-fixes image: campfire-reference:falcon-fixes sha256:3e3aede4c1165b694b8eb43121ac622537f832f7e3cd32ebc73c88e9e48c89f6 2026-10-05T19:05:58.551592135+02:00
rails-opt image: campfire-reference:rails-opt sha256:f76aaed2a8530aa612a101dcc29875ae1ae5ca412cb3957d76bc30930245b6c2 2026-10-06T18:21:11.873692394+02:00
rage image: campfire-rage:app sha256:11b0f0d055195b731a5cb7a01aeccb5cf58f73e007863a2d4dbd25baee4d4887 2026-10-06T12:59:51.721494439+02:00
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
