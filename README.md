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
| Room page | 223 | 13,634 |
| Messages page | 371 | 21,037 |
| Sidebar | 475 | 25,245 |
| Search | 377 | 16,571 |
| Post a message | 199 | 3,398 |

Room, messages and search come from an A/B on the page-assembly change (bbddf04): a fresh seed per
measurement, 4 alternating reps, medians. Sidebar and post are from the last full `bench/run`
(75f85be); that change didn't touch them. A full run of the current code is still to come.

Room, search and messages pages are assembled on every request, the way the Elixir port does it: a
kept shell around the messages, plus each message's cached fragment and compressed block. They used
to be kept whole until the database changed, which neither the Rust nor the Elixir port does. That
was worth −43% on room, −30% on search and −19% on messages (23,724 → 13,634, 23,566 → 16,571 and
25,902 → 21,037). The sidebar keeps its finished HTML until its data changes, as Elixir's does.

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
- Page ETags are built from what the page is made of, not by hashing the body. The Rust port
  hashes the cached page parts; here it's the page's inputs and message versions. Both change
  exactly when the page does.

The full list is in the
[benchmarks notes](https://github.com/jpcamara/once-campfire-sinatra/blob/benchmarks/notes/sinatra.md).

## Status

- **Parity:** the Playwright harness passes every cell on the current code. That's 874 of 874 on the
  default seed, with no allowed differences, and 82 of 82 on the other seeds: first_run 16, crowd 25,
  custom_styles 33, restricted 8.
- **Security:** an independent audit found four problems, and all are fixed:
  - stored XSS through uploads
  - no Origin check on `/cable`
  - no forgery check on cookie-authenticated bot API writes
  - fragment-marker injection
- **Other differences from Rails** the audit found are fixed too:
  - sign-out keeps the device's push subscription
  - email case at sign-in
  - bans on private IPs
  - boost length
  - no HTTPS mode
  - `X-Request-Id`, `X-Runtime` and `Date` headers
  - the CSRF meta tag, replaced by the Rust port's `file_uploader.js` override
- **One known difference:** the public-response cache is per worker process (Thruster's is one per
  container), so a repeat request that reaches another worker says `X-Cache: miss` where the
  reference says `hit`.

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
