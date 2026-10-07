# Campfire on Sinatra

[Campfire](https://github.com/basecamp/once-campfire) reimplemented on Sinatra and Falcon. It runs
on the Rails app's SQLite schema, storage layout and frontend assets unchanged, and keeps its
signed and encrypted cookies compatible, so sessions carry over. From the outside it behaves like
the Rails app. That's checked with the Playwright parity harness from DHH's
[once-campfire-rust](https://github.com/basecamp/once-campfire-rust).

One of three Ruby implementations benchmarked together. The benchmark notes, harness changes,
per-change measurements and raw results are on the
[`benchmarks` branch](https://github.com/jpcamara/once-campfire-sinatra/tree/benchmarks).

| Implementation | Code |
|---|---|
| Rails, optimized | [jpcamara/once-campfire, branch `perf`](https://github.com/jpcamara/once-campfire/tree/perf) |
| Sinatra + Falcon | this repo |
| Rage + Sequel | [jpcamara/once-campfire-rage](https://github.com/jpcamara/once-campfire-rage) |

## Design

- **Web:** Sinatra (modular) on Falcon, one forked process per CPU.
- **Database:** the `sqlite3` gem directly, without ActiveRecord. SQLite runs in WAL mode with
  `synchronous=NORMAL`, with a prepared-statement cache on each connection.
- **Views:** the reference's ERB views ported to Erubi and compiled at boot.
- **Action Cable:** implemented on `async-websocket`, with Redis pub/sub between processes.
- **Jobs:** in-process (push notifications, webhooks, bots), as in the Rust port.
- **Assets:** the reference's digested assets, served from memory.

## Performance

Requests/sec with 16 clients, four hardware threads per app, on a Hetzner Ryzen 7 PRO 8700GE.
The harness is DHH's `bench/run`. YJIT and jemalloc are on.

| HTTP workload (requests/sec) | Rails (stock) | Sinatra |
|---|---:|---:|
| Room page | 223 | *being re-measured* |
| Messages page | 371 | *being re-measured* |
| Sidebar | 475 | *being re-measured* |
| Search | 377 | *being re-measured* |
| Post a message | 199 | *being re-measured* |

The last full numbers were room 23,608, messages 26,042, sidebar 25,245, search 23,867 and post
3,398. Those included whole-page caching of the room, messages and search pages. Neither the Rust
nor the Elixir port does that, so it's being replaced with Elixir-style per-request assembly. That
change was worth about 2.5× on room in this app. Updated numbers will replace this table.

**Where the gains come from.** Each change was measured with an A/B against the commit before it.

| Change | Source | Room | Messages | Sidebar | Search | Post |
|---|---|---:|---:|---:|---:|---:|
| Split pages by byte offset | Ours (bug in our code) | +18% | — | — | +7% | — |
| Keep each page segment's deflate block | Rust | +37% | — | — | +34% | — |
| Read cache cleared on `PRAGMA data_version` | Elixir | +16% | +21% | +16% | +25% | — |
| Keep the finished sidebar until its data changes | Elixir | | | +61% | | |
| Fix: `config.ru` rebuilt the Rack stack per request | Bug fix | | | +114% | | |
| Fix: the image ran in development mode | Bug fix | +18% | | +25% | | |
| Falcon without its gzip middleware | Ours | +14% | | | | |
| Keep records built from cached rows | Ours | +14% | +15% | | | |
| Remember verified session signatures | Elixir | +12% | | +16% | | |
| Message versions as an ETag part | Rust | +7% | +8% | | | |
| Post without reloading the new message | Ours | | | | | +10% |
| WAL checkpoints in their own process | Rust | | | | | +10% |
| Plain-text bodies skip the rich-text pipeline | Ours | | | | | +38% |
| One Redis PUBLISH per post | Ours | | | | | +4% |
| Retry the write lock every 100 µs, not 1 ms | Ours | | | | | +20% |
| Public-response cache (avatars 16.4k → 82.6k req/s) | Rust, Thruster | | | | | |

"Ours" changes have no reference precedent. They're internal and invisible from outside.

## Differences from Rails

Only the ones the Rust port documents in its README under "Known differences":

- `Sec-Fetch-Site` replaces CSRF tokens.
- Jobs run in-process.
- Cookies are written only when they change.
- ETags are built from cached page parts.

The full list is in the
[benchmarks notes](https://github.com/jpcamara/once-campfire-sinatra/blob/benchmarks/notes/sinatra.md).

## Status

- **Parity:** all 874 default-seed Playwright cells pass. All other seeds are being rerun after the
  audit fixes.
- **Security:** an independent audit found stored XSS through uploads, a missing Origin check on
  `/cable`, a missing forgery check on the bot API, and fragment-marker injection. Fixes are in
  progress here; the Rage app, which shares much of this code, already has them.

## Running it

It needs the reference image `campfire-reference:app`, built with `parity/bin/reference build` in
once-campfire-rust, for the digested assets.

```sh
docker build -t campfire-sinatra:app .
docker run -p 3000:80 --env-file path/to/once-campfire-rust/parity/.env.reference \
  -v $PWD/storage/db:/rails/storage/db -v $PWD/storage/files:/rails/storage/files campfire-sinatra:app
```

For local development, `bin/dev [PORT]` runs it against a copy of the parity seed, with
once-campfire-rust checked out next to this repo.
