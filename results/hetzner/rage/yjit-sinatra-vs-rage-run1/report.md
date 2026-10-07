```
date: 2026-10-06T04:47:06+02:00
host: 6.8.0-137-generic, AMD Ryzen 7 PRO 8700GE w/ Radeon 780M Graphics, 16 threads, 61GB
server cpus: 4-7 (nproc 4); loadgen cpus: 0-3; network: host
env: WEB_CONCURRENCY=3 JOB_CONCURRENCY=3 RAILS_MAX_THREADS=5 WEB_CONCURRENCY=4 
rust extra env: 
user agent: (none)
sinatra image: campfire-sinatra:app sha256:c24a648f5a6c1fdd0ae2ee4f565edca95975ce1c3ae22c11409a6fe3785aa215 2026-10-06T03:33:28.550518498+02:00
rage image: campfire-rage:app sha256:e1a5f1d47b7bcb891f0c012cb95965c84623c031f55b1d2df06a71099e07a6de 2026-10-06T04:31:31.653481521+02:00
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
