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

Final run, Oct 7 2026: DHH's `bench/run` on a Hetzner Ryzen 7 PRO 8700GE. Each app gets four
hardware threads and the load generator four others. YJIT and jemalloc are on. The numbers are
medians of 3 runs in rotating order, measured alongside the other implementations and stock
Rails, with 0 errors.

| Workload | Rails (stock) | Sinatra |
|---|---:|---:|
| Room page (req/s, 16 clients) | 225 | 12,849 |
| Messages page | 364 | 19,729 |
| Sidebar | 482 | 23,016 |
| Search | 378 | 15,503 |
| Post a message | 198 | 3,302 |
| Avatar | 62,491 | 73,935 |
| Action Cable, 1,000 clients: p50 delivery | 42.8 ms | 9.3 ms |
| Action Cable, 1,000 clients: saturated | 13 msg/s | 103 msg/s |
| Upload + thumbnail (505 KB) | 67 ms | 135 ms |
| Idle memory (anon) | 284 MB | 200 MB |
| Cold start | 3.6 s | 1.5 s |

Uploads are about 2× slower than in Rails (135 ms vs 67 ms). An earlier run of this app measured 42 ms; the cause of the change hasn't been found.

Room, search and messages pages are assembled on every request, the way the Elixir port does it. They used to be kept whole until the database changed, which neither the Rust nor the Elixir port does. Removing that cost 43% on room, 30% on search and 19% on messages in an A/B (23,724 → 13,634, 23,566 → 16,571, 25,902 → 21,037). The sidebar keeps its finished HTML until its data changes, as Elixir's does.

**Room-page reads while posts arrive** (reads/sec at 16 clients, the median of 3 reps, each on a
fresh seed). The read routes above never see a write, so this shows what the caches do under real
traffic:

| Posts/sec in the background | 0 | 20 | 100 |
|---|---:|---:|---:|
| Rails (stock) | 228 | 214 | 194 |
| Sinatra | 12,648 | 12,096 | 8,909 |

The per-change table below comes from the A/B run for each step. Each step was measured against
the commit just before it, so the percentages don't multiply exactly into the totals.

## Compared with Rust on the same box

DHH's [Rust port](https://github.com/basecamp/once-campfire-rust) (`ccece30`) was built and run on the
same Hetzner box, in the same session as stock Rails and the three Ruby apps. Settings: 16 clients, four
hardware threads per app, median of 3 alternating reps. Each app ran with its default caching.

| HTTP workload (requests/sec) | Rails | Rails (optimized) | Sinatra | Rage | Rust |
|---|---:|---:|---:|---:|---:|
| Room page | 225 | 551 | 12,861 | 10,127 | 21,229 |
| Messages page | 360 | 1,984 | 19,729 | 24,638 | 23,565 |
| Sidebar | 480 | 3,562 | 22,936 | 32,975 | 20,828 |
| Search | 382 | 863 | 15,700 | 16,910 | 21,276 |
| Post a message | 198 | 261 | 3,195 | 1,833 | 4,153 |
| Avatar | 61,687 | 62,178 | 72,081 | 181,576 | 196,297 |
| Cable p50, 1,000 clients | 44.6 ms | 40.9 ms | 9.0 ms | 5.0 ms | 4.3 ms |
| Idle memory | 282 MB | 617 MB | 201 MB | 170 MB | 13 MB |

With only the caching Rust does (`CAMPFIRE_CACHING=rust`), the Ruby apps read at roughly a quarter to a
third of Rust's rate. Sinatra posts at three-quarters of Rust's rate. The extra caches all come from
Elixir's port, and they're what let Ruby match Rust on the messages page and sidebar.

**Hardware.** This box is slower than DHH's. On it, Rust runs at about 60% of his published numbers
(room 21,229 vs 36,260). Stock Rails runs at 73–93% of his. So comparing these numbers with his table
overstates the gap between Ruby and Rust by about 1.7×.

## Caching

The rule here: only cache what the Rust or Elixir ports cache, checked against their source.

**What the Rust port caches** (from its source):

| Cache | What it holds | Rust source |
|---|---|---|
| Message fragments | Rails' own `cache message do` fragments, in memory, bounded by bytes | `views/src/fragment_cache.rs` |
| Compressed pieces | Each fragment's deflate block, the text between fragments, and a whole body's gzip by digest | `kit/src/deflater/splice.rs` |
| Public responses | `Cache-Control: public` responses such as avatars and assets | `kit/src/front/cache.rs` |
| Prepared statements | 256 per connection | `db` crate |

Rust caches no query results and no pages, sidebars or page shells. It renders every page on every
request.

**What this app caches**, with each cache's precedent and its effect in a per-step A/B:

| Cache | Precedent | Measured effect |
|---|---|---|
| Message fragments in memory | Rust | built in |
| Compressed pieces; whole-body gzip by digest | Rust | room and search +34–37% |
| Public responses (avatars, assets) | Rust, Thruster | avatars 5× |
| Prepared statements | Rust | built in |
| Read cache (`PRAGMA data_version`), and records built from it | Elixir only | +16–25% on every read route |
| Finished sidebar until its data changes | Elixir only | sidebar +61% |
| Messages page parts per ETag | Elixir only | not measured alone |
| Room and search shell, memoized by its inputs | Elixir only | not measured alone |
| Verified session signatures | Elixir only | room +12%, sidebar +16% |
| Memoized avatar tokens, signed ids, stream names, initials | This app | not measured alone |

**Rust-level caching only.** `CAMPFIRE_CACHING=rust` turns off every cache that only the Elixir port
(or this app) has, and keeps the rest. The run used the same harness, box and CPUs as the full
run, on images built from the commit that adds the switch: 3 reps, 0 errors. Rails (stock) is from the full run; in this run it measured 221 / 365 / 467 /
368 / 196.

| Workload (req/s, 16 clients) | Rails (stock) | Full caching | Rust-level caching only | Full ÷ Rust-level |
|---|---:|---:|---:|---:|
| Room page | 225 | 12,849 | 4,812 | 2.7× |
| Messages page | 364 | 19,729 | 7,637 | 2.6× |
| Sidebar | 482 | 23,016 | 6,365 | 3.6× |
| Search | 378 | 15,503 | 7,442 | 2.1× |
| Post a message | 198 | 3,302 | 3,165 | 1.0× |

The same mixed read/write run (3 reps, fresh seed each):

| Room reads/sec while posts arrive at | 0/s | 20/s | 100/s |
|---|---:|---:|---:|
| Rails (stock) | 228 | 214 | 194 |
| Sinatra, full caching | 12,648 | 12,096 | 8,909 |
| Sinatra, Rust-level caching only | 4,763 | 4,634 | 3,741 |

## Where the gains come from

Each change was measured with an A/B against the commit before it.

| Change | Source | Room | Messages | Sidebar | Search | Post |
|---|---|---:|---:|---:|---:|---:|
| Split pages by byte offset | Ours (bug in our code) | +18% | — | — | +7% | — |
| Keep each page segment's deflate block | Rust | +37% | — | — | +34% | — |
| Read cache cleared on `PRAGMA data_version` | Elixir | +16% | +21% | +16% | +25% | — |
| Keep the finished sidebar until its data changes | Elixir | | | +61% | | |
| Fix: `config.ru` rebuilt the Rack stack per request | Bug fix | | | +114% | | |
| ~~Keep finished room / search / messages pages whole~~ | **Removed**: no precedent | (−43% when removed) | (−19%) | | (−30%) | |
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
