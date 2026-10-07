# What the Elixir and Rust ports did, and what we should copy

Sources read (read-only; no app code changed, nothing benchmarked):

- once-campfire-elixir PR #5 "Further performance improvements. Faster than Rust for some benchmarks"
  (lau, branch `further-perf`, 30 commits on top of PR #1 by zachdaniel). Cloned to
  `~/Projects/campfire-perf/once-campfire-elixir` (branches `pr5`, `pr1`). Its round notes are in
  `bench/results/further-perf-*-macos-m3-*/NOTES.md` on that branch.
- once-campfire-rust history (unshallowed; 398 commits): `plans/perf-attribution.md`,
  `plans/overnight-report.md`, `bench/results/*/report.md|summary.md`, and the perf commits from
  `3fe9f61` (Sep 27) to `ccece30` (Oct 5).
- Our apps: `apps/sinatra` (notes/sinatra.md), `apps/rage` (notes/rage.md; another agent is
  changing it now), `notes/rails-opt.md`.
- Our profiles on the box: `/opt/campfire-perf/profiles/rage-base-room.collapsed` and
  `rage-base-post.collapsed` (rbspy, c=16). Rage shares the Sinatra app's view, fragment and gzip
  code, so the room profile is a good guide for both apps.

## Published numbers next to ours

Requests/sec at 16 clients, 4 hardware threads per app. Room / messages / sidebar / search / post.

| Implementation | Machine | Room | Messages | Sidebar | Search | Post | Source |
|---|---|---:|---:|---:|---:|---:|---|
| Rails (stock) | Ryzen AI MAX+ 395 | 241 | 413 | 552 | 435 | 273 | once-campfire-rust README |
| Elixir `3498c18` (before PR #1/#5) | Ryzen AI MAX+ 395 | 722 | 1,053 | 1,275 | 1,156 | 801 | same README table |
| Go `504428a` | Ryzen AI MAX+ 395 | 3,860 | 5,573 | 19,753 | 7,053 | 4,767 | same README table |
| Rust `1ea6d6f` | Ryzen AI MAX+ 395 | 36,260 | 40,872 | 34,672 | 33,299 | 6,896 | same README table |
| Rust `3fe9f61` (Sep 27, before the page-parts work) | Apple M3, Docker Desktop | 1,566 | 3,294 | 8,385 | 3,669 | 4,948 | Elixir PR #5 `bench/results/elixir-rust-go-macos-m3-20261006/tables-rps.md` |
| Rust `ccece30` (Oct 5) | Apple M3, Docker Desktop | 26,796 | 28,335 | 27,538 | 25,488 | 6,101 | same file |
| Go `8d2f7f2` | Apple M3, Docker Desktop | 4,010 | 4,883 | 13,940 | 7,284 | 3,234 | same file |
| Elixir PR #5 round 4 (`cc47003`) | Apple M3, Docker Desktop | 17,237 | 25,238 | 32,121 | 26,790 | 1,995 | same file / PR body |
| rails-opt | Hetzner Ryzen 7 PRO 8700GE | 458 | 699 | 750 | 677 | 263 | notes/rails-opt.md |
| Sinatra + Falcon (YJIT) | Hetzner 8700GE | 2,556 | 6,822 | 4,090 | 4,155 | 1,691 | notes/rage.md (same run as Rage) |
| Rage + Sequel (YJIT) | Hetzner 8700GE | 2,483 | 7,752 | 3,922 | 4,053 | 1,428 | notes/rage.md |

Why the rows don't compare directly:

- **Different CPUs.** DHH's Ryzen AI MAX+ 395 (Zen 5) and the M3 are faster per core than our
  65 W Ryzen 7 PRO 8700GE. The M3 runs sit inside Docker Desktop's VM. Compare implementations within
  one machine's rows.
- **Different response bytes.** Elixir gzips at level 1 (room 33 KB on the wire vs Rust's 24 KB).
  Rust `3fe9f61` still had per-request CSRF tokens. Go's sidebar is a third the size of the others.
- **Elixir's read cache** keeps query results and rendered page parts until a table they read is
  written. The read routes never write, so they are served almost entirely from memory.
- **Same harness.** Our numbers come from DHH's own `bench/run` (patched only for the box), the same
  seed and loadgen. The method matches; the hardware doesn't.

The useful number is CPU per request at c=16 (4 CPUs saturated). On the room page: Rust about
0.11 ms (DHH's machine), Elixir round 4 about 0.2 ms (M3), Sinatra about 1.6 ms, Rage about 1.6 ms,
rails-opt about 8.7 ms. That gap is what the list below goes after.

## How Rust went from 1,566 to 26,796 on the room page (M3 numbers) in a week

In order, with the Rust repo's own measurements (native builds, 4 pinned cores, 16 clients):

| Commit / PR | Change | Measured there |
|---|---|---|
| `abcaa09` (#1) | Splice precompressed message fragments into the gzipped page | room 2.16×, messages 4.45×, search 2.60× (`bench/results/splice-20260927`) |
| `b567772` (#2) | `Sec-Fetch-Site` instead of CSRF tokens: pages are byte-stable, ETags repeat | room +9%, messages +6%, search +10% (`header-csrf-20260927`) |
| `aa3b894` (#3) | `(room_id, created_at)` index on boot; `paged?` without `COUNT(*)` | 64×/208× on a 236k-message room (`room-index-20260927`) |
| `2947c64`, `e279519` (#4) | Cache every part of the page (layout text too), compressed once against its predecessor; ETag from part digests; cookies only when changed | room 2.9×, search 2.8×, messages 1.3× (`page-parts-20260927`) |
| `41de833` (#15) | Keep the compressed form of every page, also pages without fragments | sidebar 1.82× (`whole-page-parts-20260929`) |
| `5368537` (#32) | Reads on dedicated reader threads; merged round trips | room +8–15%, search +29–44% (`db-hops-20260930`) |
| `2f755bf` (#43, emoon) | Pages from *recorded* parts (no marker search); CRC combined from parts; buffers presized from the last render; whole-body gzip kept by SHA-256 | room +45%, messages +43%, sidebar +21%, post +10% (`inline-reads-recorded-parts-20260930`) |
| `786a74d` and earlier pass | WAL checkpoints on their own thread; prepared statements everywhere; fragments shared not copied; sidebar `LIMIT` inlined; stylesheet tags once per process; fat LTO + jemalloc | POST p99 12.5 → 1.7 ms; POST 4,257 → 4,693; messages 2,233 → 2,666 (`plans/overnight-report.md`) |
| cable pass (`4e77f67`…) | 4 KiB read buffer, frame encoded once per subscriber set, batched writes | 4.7× less CPU per delivery (`plans/overnight-report.md`) |

The pattern: once CSRF tokens left the page, almost everything around the messages became
cacheable, and the remaining per-request work shrank to auth, a few reads and splicing stored
compressed bytes.

## How Elixir PR #5 went from 2,057 to 17,237 on the room page (M3)

From the round notes (CPU per request at c=16, clean reps):

| Round | Commits | Change | Effect |
|---|---|---|---|
| 1 | `7b32d37`, `75b97f4`, `449efed`, `0ded9b0`, `d3294b2` | Thruster replaced in-process; Sec-Fetch-Site CSRF; paging index; session_token re-signed only hourly; session + user in one query; ETag from fragment digests; invitation count stops at 41 | room 2.3×, messages 2.4×, search 2.5×, post 1.4×, /up 4.9× |
| 2 | `03874d7` | Messages and search pages spliced too; the page's per-request text compressed once and kept (key: text SHA-256 + dictionary); sidebar direct-room members in one query; avatar signatures memoized; one account query per page; single-pass escaping | messages 2.38×, room/sidebar/search ~1.47× |
| 3 | `a34e991` | Room shell kept under a SHA-256 of its template inputs; messages page parts and gzip kept per ETag; verified session cookie kept (expiry still checked); User-Agent parse kept per header value; one paging query | room −15–20% CPU, messages −10–15% |
| 4 | `050d2d0`, `be3423b`, `ab362d2`, `cc47003` | Read cache by table generations (other writers caught through the WAL index header); pipeline trims (header parsing memoized, no cookie parse without a session cookie, whole-body gzip kept by digest); sidebar kept by table generations; search shell by inputs; post 31 → 16 SQL statements | room 2.2×, messages 2.6×, sidebar 5.5×, search 4.5×, post −23% CPU, /up −36% |

The PR's own summary of what helped most: the read cache and the cached sidebar (round 4),
reusing compressed message HTML (round 2), and removing Thruster and CSRF tokens (round 1).

## What our room page spends its time on

Rage room page, rbspy at c=16 (`profiles/rage-base-room.collapsed`, 7,346 active samples). The
fragment and gzip code is the Sinatra app's.

| Where | Share |
|---|---|
| `FragmentBody.from`: `String#scan` + `String#[]` + `MatchData#begin` splitting the rendered page on its markers | ~24% |
| `Zlib::Deflate#deflate`: compressing the page's own text (head, nav, composer, tail) every request | ~20% |
| Database (Sequel + SQLite step), incl. `Runtime#account` 7.8% (the account is queried every request) | ~24% (Rage; Sinatra's raw sqlite3 is cheaper) |
| Templates around the messages: `tpl_rooms_nav` 10.6%, `tpl_layouts_application` 8.1%, composer, PWA settings | ~25% |
| Run-cache keys (`Array#hash`, `Array#eql?`), HMAC cookie check, rest | ~7% |

The first row is a plain bug. `html[last...match.begin(0)]` uses character offsets, and the page
has multi-byte characters, so every slice and every `begin` walks the string from the start. A
micro-benchmark of the same loop on a 30 KB UTF-8 page with 50 markers (`tools/scan_bench.rb`,
Ruby 3.4.5 + YJIT on the Mac): 1,056 µs with character offsets, 163 µs with
`MatchData#byteoffset` + `String#byteslice`, same output. On an ASCII page it's 139 vs 109 µs.

Posting (`profiles/rage-base-post.collapsed`): `COMMIT` is 29% of the post's samples (SQLite
step inside `commit_transaction`), and re-loading the new message's view from the database
(`Messages.views`, cached: false) is 21%.

## Ranked candidates

Gain ÷ effort, best first. "Have it" = Sinatra / Rage / rails-opt. Expected gains are estimates
from the profile shares above unless marked measured; each needs an A/B on the box before it's kept.

| # | Optimization | Source | Measured there | Have it (S / R / Rails) | Expected for us | Effort | Parity risk |
|---|---|---|---|---|---|---|---|
| 1 | **Byte offsets when splitting a page on fragment markers** (`byteoffset` + `byteslice`); later, record the parts while rendering instead of scanning (Rust's recorded parts) | our profile; Rust `2f755bf` | Rust: recorded parts −14–16% CPU on room/messages | no / no / n.a. | room, messages, search −15–25% CPU (micro-bench: 1,056 → 163 µs per page) | ~10 lines | none: same bytes (test that parts join to the same string) |
| 2 | **Cache compressed text segments by content.** Keep each literal segment's deflate block (and CRC) in an LRU keyed by the segment string, like `RunCache` does for message runs | Rust `2947c64`; Elixir `03874d7` | Rust room 2.9× / search 2.8× (with ETag-from-parts); Elixir messages 2.4×, room 1.46× | runs only / runs only / n.a. | room, search −15–20% CPU (deflate is 20% of room) | small | none: decoded body identical; segments are already compressed independently |
| 3 | **Keep a whole body's gzip by its digest.** In `Compression`, when `ETag` has hashed a non-fragment body, reuse the gzip stored under that MD5 | Rust `2f755bf` (`GZIPPED`); Elixir `be3423b` | Rust sidebar part of 1.82× (`41de833`) | no / no / n.a. | sidebar −10–20% CPU; every other non-fragment page | ~20 lines | none |
| 4 | **Read cache invalidated by `PRAGMA data_version`.** Per process, memoize read results by (SQL, binds). At request start, compare the reader connection's `data_version` with the last seen value and clear on change (it changes on any other connection's commit, including our own writer and other workers). Clear after our own commits too. Cache only reads with pure binds (no `now`) | Elixir `050d2d0` (per-table generations; WAL-index check for outside writers) | Elixir round 4: sidebar 5.5×, search 4.5×, room 2.2×, messages 2.6× (with #5–#7) | no / no / no | sidebar, search 1.3–2×; room, messages 1.1–1.3× in Sinatra; more in Rage (DB is 24% of its room page). Account lookup (7.8%) disappears | medium | low–medium: per-table generations are finer, but `data_version` is exact and works across processes; any write clears all, which only matters under mixed load |
| 5 | **Cache the sidebar response** (HTML, gzip, ETag) under the read-cache epoch + user + flash + frame header + user agent | Elixir `ab362d2` | Elixir sidebar part of 5.5× | no / no / no | sidebar 3–5× | small after #4 | low: the Redis direct-room fragments it embeds are deterministic per key, so Rails' stale-unread behaviour is kept |
| 6 | **Messages page: keep the finished response per ETag.** The ETag already covers every message version and the request inputs; on a hit, skip `Last-Modified` parsing of 50 timestamps, fragment assembly, split and gzip | Elixir `a34e991` | Elixir messages −10–15% CPU on top of round 2 | no / no / n.a. | messages 1.3–1.6× | small | low: key = the ETag + base URL + Accept-Encoding |
| 7 | **Cache the page shell around the messages by its inputs** (room and search pages). `page_etag` already lists the inputs (base URL, UA, user id/updated_at/role, room, account, invitation, direct names, flash). Store the shell's text parts and their compressed blocks under that digest; per request only splice | Elixir `a34e991`, `ab362d2`; Rust `2947c64` | Elixir room −15–20% CPU after rounds 1–2; Rust room 2.9× | no / no / no (needs no CSRF tokens) | room, search 1.3–1.5× on top of #1–#4 | medium | medium: every input that changes the shell must be in the key. Add a check mode that renders both and compares, and run it through the parity harness |
| 8 | **WAL checkpoints off the request path.** `wal_autocheckpoint=0` on app connections; one background checkpointer (one worker, one thread) runs `wal_checkpoint(PASSIVE)` when the WAL passes ~1,000 pages or every ~200 ms | Rust overnight pass; `plans/perf-attribution.md` §5 | Rust POST p99 12.5 → 1.7 ms; up to 2.2× POST throughput on disk | no / no / no | post +20–60% (COMMIT is 29% of the Rage post profile; confirm it's checkpoints first) | small–medium | none: same journal mode and durability |
| 9 | **Lean post.** Render the new message's fragment from the records the request holds (no re-query: Sinatra's `message_views([message])` runs 5 queries); one Redis pipeline for the per-member unread publishes (one `PUBLISH` per member today); push job reads involvement in its join, not per subscription | Elixir `cc47003` (31 → 16 statements) | Elixir post −23% CPU (with the read cache) | no / no / no (rails-opt lists the push N+1) | post +15–25% | small–medium | low: test that the fragment equals a fresh render from the database |
| 10 | **Thruster-style cache for public responses** (avatars, logo, QR codes): in-memory, keyed by method + path + raw query + encoding, honouring `max-age`, `X-Cache: hit` like Thruster | Rust `fa1deb9`, `266f547` | Thruster/Rust serve avatars from cache (falcon-fixes 61,733 vs Sinatra 10,689 req/s on our box) | no / no / via Thruster | avatar ~5× | small | low; it brings `X-Cache` closer to Thruster's (hit after the first request) |
| 11 | **Pipeline trims.** Answer `/up` and assets in a Rack middleware ahead of Sinatra; memoize `Browsers.blocked?` and `Platform` per User-Agent string; memoize a verified `session_token` cookie (check expiry each time); inline constant `LIMIT`s in `ORDER BY` queries (`last_page`, `page_before`, placeholder users); invitation check as `LIMIT 1 OFFSET 50` instead of `COUNT(*)` | Elixir `a34e991`, `be3423b`; Rust `e89cc43`, user-agent (`user-agent-20260930`), `aa3b894` | Elixir pipeline −36% (/up 69 → 42 µs); Rust UA parse ~4×, sidebar LIMIT −5.5% | partly / partly / n.a. | /up 2–3× on Sinatra; pages a few % (the bench sends no UA, real browsers do) | trivial each | none |
| 12 | **Cable writes (Sinatra).** Sinatra already shares the JSON per identifier and flushes when the outbox empties. Left: one WebSocket frame encoding per subscriber set, writev of queued frames, and fewer Redis hops for same-process subscribers | Rust cable pass; Elixir PR #1 batched Bandit writes (+60%) | Rust 4.7× less CPU per delivery | partly / Iodine does it in C / n.a. | uncertain; Rage is already 1.7–1.8× Sinatra here | medium | none |

### Already done in our apps (no action)

- Fragment lookup before building the view (Rust perf-attribution #3): Sinatra and Rage
  (`Messages.views` loads only misses).
- Message runs spliced as stored deflate blocks with a combined CRC (Rust `abcaa09`, Elixir
  `03874d7`): Sinatra and Rage (`RunCache`).
- Sec-Fetch-Site instead of CSRF tokens; cookies written only when they change; session_token
  re-signed hourly (Rust `b567772`, `2947c64`; Elixir `75b97f4`, `0ded9b0`): Sinatra and Rage.
- ETag from inputs instead of hashing the 450 KB body: Sinatra and Rage (`page_etag`).
- `(room_id, created_at)` index: in the reference schema already.
- Prepared statements cached per connection: Sinatra (raw sqlite3). Rage goes through Sequel's
  prepared statements, which cost ~24% of its room page; the Rage agent is changing `db.rb` now.
- In-process jobs, in-memory static files, jemalloc, YJIT.

### rails-opt

Items 2, 4–7 depend on pages being identical across requests, which needs the CSRF tokens gone
(the Rust port's documented divergence, which rails-opt has not taken: its bar is byte-identical to
stock Rails). Without that, what carries over is item 8 (checkpoints), item 9 (post statements and
the push N+1, already listed in notes/rails-opt.md), and fragment caching of the composer (16%) and
bell (7%) with the token left live.

## Suggested order

1, 3 and 11 are an afternoon and safe. Then 2 and 6. Then 4 with 5, which is where Elixir's
biggest step came from. Then 7, 8 and 9. Measure each with alternating A/B on the box and keep
the parity diff and Playwright batches green. Items 1–7 apply to both Sinatra and Rage, since they
share the view and gzip code; port once, apply to both.
