# Campfire on Sinatra

[Campfire](https://github.com/basecamp/once-campfire) reimplemented on Sinatra and Falcon. It runs
on the Rails app's SQLite schema, storage layout and frontend assets unchanged, and keeps its
signed and encrypted cookies compatible, so sessions carry over. From the outside it behaves like
the Rails app. That's checked with the Playwright parity harness from DHH's
[once-campfire-rust](https://github.com/basecamp/once-campfire-rust).

One of four Ruby implementations benchmarked together. The benchmark notes, harness changes,
per-change measurements and raw results are on the
[`benchmarks` branch](https://github.com/jpcamara/once-campfire-sinatra/tree/benchmarks).

| Implementation | Code |
|---|---|
| Rails, optimized (retired Oct 10; use [upstream](https://github.com/basecamp/once-campfire)) | [jpcamara/once-campfire, branch `perf`](https://github.com/jpcamara/once-campfire/tree/perf) |
| Sinatra + Falcon | this repo |
| Rage + Sequel | [jpcamara/once-campfire-rage](https://github.com/jpcamara/once-campfire-rage) |
| Roda + Sequel (Falcon) | [jpcamara/once-campfire-roda](https://github.com/jpcamara/once-campfire-roda) |

## Design

- **Web:** Sinatra (modular) on Falcon, one forked process per CPU.
- **Database:** the `sqlite3` gem directly, without ActiveRecord. SQLite runs in WAL mode with
  `synchronous=NORMAL`, with a prepared-statement cache on each connection.
- **Views:** the reference's ERB views ported to Erubi and compiled at boot.
- **Action Cable:** implemented on `async-websocket`, with Redis pub/sub between processes.
- **Jobs:** in-process (push notifications, webhooks, bots), as in the Rust port.
- **Assets:** the reference's digested assets, served from memory.

## Performance

Final run, Oct 8 2026, after the precedent audit: DHH's `bench/run` on a Hetzner Ryzen 7 PRO
8700GE. Each app gets four hardware threads and the load generator four others. YJIT and jemalloc
are on. The numbers are medians of 3 runs in rotating order (HTTP and Action Cable), measured
alongside the other implementations, stock Rails and the Rust port, with 0 errors. Upload and
cold-start times are from the Oct 7 run; the audit's reverts don't touch those paths.

| Workload | Rails (stock) | Sinatra |
|---|---:|---:|
| Room page (req/s, 16 clients) | 221 | 11,349 |
| Messages page | 370 | 16,256 |
| Sidebar | 482 | 22,613 |
| Search | 381 | 14,523 |
| Post a message | 195 | 1,799 |
| Avatar | 61,938 | 72,664 |
| Action Cable, 1,000 clients: p50 delivery | 44.1 ms | 8.2 ms |
| Action Cable, 1,000 clients: saturated | 12 msg/s | 104 msg/s |
| Idle memory (anon) | 283 MB | 200 MB |
| Upload + thumbnail (505 KB), Oct 7 run | 67 ms | 135 ms |
| Cold start, Oct 7 run | 3.6 s | 1.5 s |

Uploads are about 2× slower than in Rails (135 ms vs 67 ms). An earlier run of this app measured 42 ms; the cause of the change hasn't been found.

Room, search and messages pages are assembled on every request, the way the Elixir port does it. They used to be kept whole until the database changed, which neither the Rust nor the Elixir port does. Removing that cost 43% on room, 30% on search and 19% on messages in an A/B (23,724 → 13,634, 23,566 → 16,571, 25,902 → 21,037). The sidebar keeps its finished HTML until its data changes, as Elixir's does.

The precedent audit (Oct 8) then reverted every optimization with no Rust or Elixir counterpart. Most of
them were on the post path, so posting fell from 3,195 to 1,799 req/s; room fell 12% and messages 18%.

**Room-page reads while posts arrive** (reads/sec at 16 clients, the median of 3 reps, each on a
fresh seed). The read routes above never see a write, so this shows what the caches do under real
traffic:

| Posts/sec in the background | 0 | 20 | 100 |
|---|---:|---:|---:|
| Rails (stock), Oct 7 run | 228 | 214 | 194 |
| Sinatra | 11,253 | 10,806 | 7,748 |

The per-change table below comes from the A/B run for each step. Each step was measured against
the commit just before it, so the percentages don't multiply exactly into the totals.

## Finished-page cache (Oct 10)

Upstream Rails now keeps finished private pages until the database changes
([ac73267](https://github.com/basecamp/once-campfire/commit/ac73267),
[0f5d0b2](https://github.com/basecamp/once-campfire/commit/0f5d0b2),
[8d02540](https://github.com/basecamp/once-campfire/commit/8d02540)), following the C port. The Rust
port added the same thing
([d09811c](https://github.com/basecamp/once-campfire-rust/commit/d09811c),
`crates/campfire/src/response_cache.rs`). So this app does it too (`lib/campfire/page_cache.rb`):

- **What's kept:** the room, messages, sidebar and search pages of a signed-in user, body and gzip.
- **When it's dropped:** any SQLite commit from any process clears it (`PRAGMA data_version`). The
  version is captured before authentication and checked again at lookup and admission, so a commit
  during a render can't leave a stale page under the new version. Entries also expire after 15
  seconds, as Rust's do.
- **What still runs on every request:** authentication, the room access check and cookies.
- **Not kept:** pages with a flash, conditional requests, and responses that set a cookie.
- **Bounds:** `CAMPFIRE_RESPONSE_CACHE_MB` per process (default 64, 0 turns it off), 1 MB per page.
  Concurrent renders of one page collapse into one.
- **`CAMPFIRE_CACHING=rust`** keeps this cache on, since the Rust port has it.

**Checks:** every Playwright cell on every seed passes (default 874, crowd 25, custom_styles 33,
first_run 16, restricted 8). Server HTML matches the reference on 128 of 128 pages, fresh and
cached. All 24 write flows match. With the cache on and off, 60 requests across these scenarios
give identical statuses: foreign writes to a message body and to a user's name, a revoked
membership, a banned user, a deleted session. Every read after a foreign write shows it. Check mode
(`CAMPFIRE_CHECK_CACHES=1`) found 0 mismatches across reads, posts and foreign writes from all 4
processes.

Measured with DHH's verification harness
([basecamp/once-campfire-verification](https://github.com/basecamp/once-campfire-verification)
`ec02deb`) on the Hetzner box: app on CPUs 4-7, load generator on 0-3, 3 rounds, 8-second samples.
Upstream Rails `0aa339d` and Rust `6dae2fd` ran in the same session. Every response passed the
harness's route checks, and every write passed its audit, with 0 errors or invalid responses.

| Requests/sec, 16 clients | Sinatra before | **Sinatra with page cache** | Rails (upstream) | Rust |
|---|---:|---:|---:|---:|
| Room page | 11,062 | **22,266** | 3,189 | 42,282 |
| Messages page | 15,921 | **23,808** | 3,206 | 40,615 |
| Sidebar | 21,947 | **22,403** | 3,568 | 48,314 |
| Search | 14,091 | **22,008** | 3,450 | 47,564 |
| Post a message | 1,930 | **1,973** | 282 | 4,792 |

Mixed profile (16 readers plus one writer at 10 posts/sec, read requests/sec):

| Read requests/sec | Sinatra before | **Sinatra with page cache** | Rails (upstream) | Rust |
|---|---:|---:|---:|---:|
| Room page | 10,328 | **20,703** | 1,545 | 39,564 |
| Messages page | 14,659 | **22,143** | 1,875 | 37,997 |
| Sidebar | 21,287 | **21,605** | 2,838 | 46,939 |
| Search | 14,464 | **22,410** | 2,580 | 46,151 |

"Before" is the same harness earlier on Oct 10, without this cache.

## Compared with Rust on the same box

DHH's [Rust port](https://github.com/basecamp/once-campfire-rust) (`ccece30`) was built and run on the
same Hetzner box, in the same Oct 8 session as stock Rails and the three Ruby apps. Settings: 16 clients,
four hardware threads per app, median of 3 runs in rotating order. Each app ran with its default caching.

| HTTP workload (requests/sec) | Rails | Rails (optimized) | Sinatra | Rage | Rust |
|---|---:|---:|---:|---:|---:|
| Room page | 221 | 529 | 11,349 | 10,094 | 21,155 |
| Messages page | 370 | 1,985 | 16,256 | 24,763 | 23,515 |
| Sidebar | 482 | 3,557 | 22,613 | 33,951 | 20,769 |
| Search | 381 | 862 | 14,523 | 16,900 | 21,361 |
| Post a message | 195 | 259 | 1,799 | 1,643 | 4,109 |
| Avatar | 61,938 | 62,671 | 72,664 | 178,292 | 196,428 |
| Cable p50, 1,000 clients | 44.1 ms | 41.1 ms | 8.2 ms | 5.0 ms | 4.4 ms |
| Idle memory | 283 MB | 613 MB | 200 MB | 170 MB | 13 MB |

With only the caching Rust does (`CAMPFIRE_CACHING=rust`), the Ruby apps read at roughly a quarter to
two-fifths of Rust's rate, and post at about 40–45% of it. The extra caches all come from Elixir's port,
and they're what let Ruby match Rust on the messages page and sidebar.

**Hardware.** This box is slower than DHH's. On it, Rust runs at about 60% of his published numbers
(room 21,155 vs 36,260). Stock Rails runs at 73–93% of his. So comparing these numbers with his table
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
| Finished private pages (added Oct 7) | Room, messages, sidebar and search pages, until a commit or 15 s | `campfire/src/response_cache.rs` (d09811c) |

Rust caches no query results, sidebars or page shells. Since Oct 7 it keeps finished private pages
until the next commit, as upstream Rails and the C port do; on a miss it renders the whole page.

**What this app caches**, with each cache's precedent and its effect in a per-step A/B:

| Cache | Precedent | Measured effect |
|---|---|---|
| Message fragments in memory | Rust | built in |
| Compressed pieces; whole-body gzip by digest | Rust | room and search +34–37% |
| Public responses (avatars, assets) | Rust, Thruster | avatars 5× |
| Prepared statements | Rust | built in |
| Finished private pages until the database changes | Rust (d09811c), upstream Rails (ac73267), C | room 2.0×, search 1.6×, messages 1.5× |
| Read cache (`PRAGMA data_version`) | Elixir only | +16–25% on every read route |
| Finished sidebar until its data changes | Elixir only | sidebar +61% |
| Messages page parts per ETag | Elixir only | not measured alone |
| Room and search shell, memoized by its inputs | Elixir only | not measured alone |
| Verified session_token cookie | Elixir only (`auth.ex`) | room +12%, sidebar +16% |
| Memoized avatar tokens | Elixir only (`mentions.ex`) | not measured alone |

**Rust-level caching only.** `CAMPFIRE_CACHING=rust` turns off every cache that only the Elixir port
has, and keeps the rest. It ran on Oct 8 with the same harness, box, CPUs and images as the full
run: 3 runs in rotating order, HTTP suite, 0 errors. Rails (stock) is from the full run.

| Workload (req/s, 16 clients) | Rails (stock) | Full caching | Rust-level caching only | Full ÷ Rust-level |
|---|---:|---:|---:|---:|
| Room page | 221 | 11,349 | 4,911 | 2.3× |
| Messages page | 370 | 16,256 | 7,798 | 2.1× |
| Sidebar | 482 | 22,613 | 6,403 | 3.5× |
| Search | 381 | 14,523 | 7,641 | 1.9× |
| Post a message | 195 | 1,799 | 1,817 | 1.0× |

The same mixed read/write run (3 reps, fresh seed each):

| Room reads/sec while posts arrive at | 0/s | 20/s | 100/s |
|---|---:|---:|---:|
| Rails (stock), Oct 7 run | 228 | 214 | 194 |
| Sinatra, full caching | 11,253 | 10,806 | 7,748 |
| Sinatra, Rust-level caching only | 4,782 | 4,710 | 3,711 |

## Where the gains come from

Each change was measured with an A/B against the commit before it. Every change is a fix of our own
bug, something the Rust port does, or a cache the Elixir port has. Changes with neither precedent
were reverted (see below), as listed in
[the precedent audit](https://github.com/jpcamara/once-campfire-sinatra/blob/benchmarks/notes/precedent-audit.md).

| Change | Source | Room | Messages | Sidebar | Search | Post |
|---|---|---:|---:|---:|---:|---:|
| Split pages by byte offset | Bug fix | +18% | — | — | +7% | — |
| Keep each page segment's deflate block | Rust (2947c64) | +37% | — | — | +34% | — |
| Read cache cleared on `PRAGMA data_version` | Elixir (`db.ex`) | +16% | +21% | +16% | +25% | — |
| Keep the finished sidebar until its data changes | Elixir (`sidebar.ex`) | | | +61% | | |
| Fix: `config.ru` rebuilt the Rack stack per request | Bug fix | | | +114% | | |
| Fix: the image ran in development mode | Bug fix | +18% | | +25% | | |
| Falcon without its own gzip layer (the app already compresses once) | Bug fix | +14% | | | | |
| Remember the verified session_token cookie | Elixir (`auth.ex`) | +12% | | +16% | | |
| WAL checkpoints in their own process | Rust (`db/src/database.rs`) | | | | | +10% |
| `/assets` and `/cable` dispatched before routing | Rust (`app.rs`) | +5–8% on small routes | | | | |
| Public-response cache (avatars 16.4k → 82.6k req/s) | Rust (`front/cache.rs`), Thruster | | | | | |

**Reverted for lack of precedent.** Each was measured as a gain when it was added:

| Reverted change | Gain it had | Why |
|---|---|---|
| Keep finished room / search / messages pages whole | room +145%, messages +56%, search +80% | neither port keeps whole pages |
| Plain-text bodies skip the rich-text pipeline | post +38% | Rust parses every body |
| Retry the write lock every 100 µs, not 1 ms | post +20% | Rust has one writer thread and never retries |
| Build a new message's view and push payload from the request | post +10% | Rust reads them back through its presenter |
| One Redis PUBLISH per post | post +4% | Rust broadcasts one by one |
| Keep records built from cached rows | room +14%, messages +15% | Elixir caches rows, not records |
| Memoize the ETag's message-version list | room +7%, messages +8% | Rust builds ETag parts per request |
| Remember every verifier's signatures, signed stream names and blob ids, initials SVGs | not measured alone | Rust generates each per use; Elixir only keeps the session cookie |

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

- **Parity:** the Playwright harness passed every cell before the precedent audit: 874 of 874 on the
  default seed, with no allowed differences, and 82 of 82 on the other seeds (first_run 16, crowd 25,
  custom_styles 33, restricted 8). After the audit's reverts, the groups they touch passed again, 408 of 408
  (auth, realtime, composer, users, messages). Server HTML matches the reference on 128 of 128 pages
  (fresh and cached), and all 24 write flows match.
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
