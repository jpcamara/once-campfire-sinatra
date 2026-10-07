```
date: 2026-10-06T00:27:58+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
sinatra image: campfire-sinatra:app sha256:be7822b8e3f292eeebeb82f16dbcb28b2ec672f7e2a528dd57a2e019abd4bad6 2026-10-06T00:15:25.416358767+02:00
falcon-fixes image: campfire-reference:falcon-fixes sha256:3e3aede4c1165b694b8eb43121ac622537f832f7e3cd32ebc73c88e9e48c89f6 2026-10-05T19:05:58.551592135+02:00
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
