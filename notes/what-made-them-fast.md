# What made each Campfire implementation fast

Measured with DHH's harness (`bench/run` from once-campfire-rust) on a Hetzner Ryzen 7 PRO 8700GE.
Each app gets 4 hardware threads, the load generator gets 4 others, and there are 16 clients.
Results are requests/sec, median of 3 alternating runs, with YJIT and jemalloc on for every app.

| HTTP workload (requests/sec) | Rails (stock) | Rails (optimized) | Sinatra | Rage |
|---|---:|---:|---:|---:|
| Room page | 225 | 538 | 12,849 | 10,127 |
| Messages page | 364 | 2,003 | 19,729 | 24,569 |
| Sidebar | 482 | 3,578 | 23,016 | 34,134 |
| Search | 378 | 872 | 15,503 | 16,837 |
| Post a message | 198 | 258 | 3,302 | 1,848 |

These are from the final run on Oct 7, 2026, with all four apps measured together, 3 rotating
reps, and 0 errors. Whole-page caching of the room, search and messages pages has been removed
from all three apps, because neither the Rust nor the Elixir port does it. The per-change tables
below come from the A/B run for each step, and the "Removed" rows show what that caching was
worth.

**Ground rules.** Every app has to match the Rails reference as a black box. That's checked with
DHH's Playwright parity harness plus server-HTML diffs. The only differences allowed are the ones
the Rust port documents in its README under "Known differences". The one that matters most:
`Sec-Fetch-Site` replaces CSRF tokens, so a page renders the same for everyone until its content
changes, and that makes pages cacheable.

## Rails (optimized)

The base is stock once-campfire. These were config fixes first, then code changes. Everything
below was measured one change at a time.

**Config**
- Falcon in place of Puma (`isolation_level = :fiber`), with 4 processes. Stock Rails runs
  3 Puma workers.
- Removed `use Rack::Deflater` from `config.ru`, because Thruster already gzips.
- Redis cache store set to `compress: false`. Inflating with zlib was about 40% of the room page.

**First pass** (output byte-identical to stock)
- Skip the static-file middleware's disk checks for paths outside `public/` (it was doing up to
  9 per request).
- Render the stylesheet and importmap tags once per process.
- Load `Current.account` once per request instead of with 4+ queries.
- Keep a per-process copy of each versioned Redis fragment (`FragmentCacheStore`). This was the
  biggest first-pass win.
- Work out cache versions without checking out a database connection.
- Build the 8 boost forms on each message as strings.

**Second pass** (taking the Rust port's divergences)
- Hand-rolled the `Sec-Fetch-Site` check, matching Rails main's `protect_from_forgery using:
  :header_only`. `file_uploader.js` is overridden so it no longer sends a token.
- Keep each page's gzip by body digest.
- Read cache, cleared when `PRAGMA data_version` changes.
- Keep finished sidebar, room, messages and search responses until the database changes, with a
  check mode that re-renders each hit and compares.
- Write cookies only when they change.
- Push job: preload users, one badge count per user.
- Bug fix: request bodies weren't rewindable under Falcon, which broke the bot API.

**Tried and dropped:** PostgreSQL (slower when it shares the same 4 CPUs), putting each post in
one transaction, and in-process jobs (posting was −16% because single-threaded Falcon processes
block on SQLite).

**Effect of each change.** Each step was A/B tested against the commit just before it (requests/sec
at 16 clients, median of 3–5 alternating reps). Every step had its own baseline, so the
percentages don't multiply into the totals exactly. A dash means no notable change on that route.

| Change | Room | Messages | Sidebar | Search | Post |
|---|---:|---:|---:|---:|---:|
| No `Rack::Deflater`, Redis `compress: false`, no `Rack::ETag`, 4 workers (measured together) | +56% | +52% | +19% | +31% | +19% |
| Puma → Falcon | +1% | +3% | +10% | +12% | +1% |
| Static-file checks skipped + tags once per process + `Current.account` once (together) | +10% | — | +14% | +14% | — |
| Per-process fragment copies + cache versions without a DB checkout (together) | +13% | +20% | +6% | +8% | — |
| Boost forms as strings | — | +2% | — | — | +8% |
| `Sec-Fetch-Site` instead of CSRF tokens | +14% | +16% | — | +9% | — |
| Keep each page's gzip by digest | +7% | +20% | +7% | — | — |
| Read cache (`PRAGMA data_version`) | — | +10% | +16% | +14% | — |
| Keep the finished sidebar | | | +227% | | |
| Keep finished room / messages / search | +352% | +129% | | +254% | |
| Cookies only when they change | +17–23% on every read route | | | | |
| Push job query fixes | | | | | +1% |
| Restore `Rack::Deflater` (needed for parity) | −1–3% on every route | | | | |

From Falcon + config fixes to the final optimized app: room +742%, messages +416%, sidebar +491%,
search +565%, post +12%. Almost all of the read gain comes from keeping finished pages until the
next write, and the CSRF change is what made that possible.

## Sinatra

A rewrite on Sinatra and Falcon.

**Architecture:** the `sqlite3` gem used directly with a prepared-statement cache (no
ActiveRecord); ERB views ported to Erubi and compiled at boot; Action Cable implemented natively
over `async-websocket`, with Redis pub/sub between workers; jobs run in-process.

**What made it fast**
- Fixed two bugs. `config.ru` was rebuilding the whole Rack stack on every request, and the image
  ran in development mode.
- Cache message fragments with their deflate blocks already computed, so a page is spliced, not
  recompressed.
- Split pages by byte offset rather than character offset. On UTF-8 pages, slicing by character
  was about 24% of the room page's CPU.
- Keep each page segment's deflate block, and keep a whole body's gzip under its MD5.
- Read cache cleared on `PRAGMA data_version`, checked on every request.
- Keep finished sidebar, room, messages and search responses until the next write, with a check
  mode.
- Keep the records built from cached rows, and remember session signatures already verified.
- Serve static files from memory, plus a Thruster-style cache for public responses (avatars).
- Host Falcon without its ContentEncoding middleware, and route `/assets` and `/cable` by prefix.

**Posting** (1,678 → 3,398)
- WAL checkpoints run in their own process, and only once 1,000 frames are waiting. Before,
  SQLite's auto-checkpoint fsynced inside commits while holding the write lock.
- Plain-text messages skip the Nokogiri sanitizer pipeline.
- Retry a busy write lock every 100 µs instead of every 1 ms.
- One Redis PUBLISH per post instead of one per member, and the new message is rendered without
  reloading it.

**Effect of each change.** Same method as the Rails table: an A/B against the commit before, at 16
clients. The Source column says where the idea came from. "Ours" means it has no reference
precedent; those changes are internal and invisible from outside.

| Change | Source | Room | Messages | Sidebar | Search | Post |
|---|---|---:|---:|---:|---:|---:|
| Split pages by byte offset | Ours (bug in our code) | +18% | — | — | +7% | — |
| Keep each page segment's deflate block | Rust | +37% | — | — | +34% | — |
| Keep a body's gzip under its MD5 | Rust, Elixir | +1% | | | | |
| Post without reloading the new message | Ours | | | | | +10% |
| Read cache (`PRAGMA data_version`) | Elixir | +16% | +21% | +16% | +25% | — |
| Keep the finished sidebar | Elixir | | | +61% | | |
| Fix: `config.ru` rebuilt the Rack stack per request | Bug fix | | | +114% | | |
| ~~Keep finished room / messages / search~~ | **Removed**: no precedent | +145% | +56% | | +80% | |
| Fix: the image ran in development mode | Bug fix | +18% | | +25% | | |
| Falcon without its ContentEncoding middleware | Ours | +14% | | | | |
| Keep records built from cached rows | Ours | +14% | +15% | | | |
| Remember verified session signatures | Elixir | +12% | | +16% | | |
| Public-response cache (avatars: 16.4k → 82.6k) | Rust, Thruster | | | | | |
| WAL checkpoints in their own process | Rust | | | | | +10% |
| Plain-text bodies skip the rich-text pipeline | Ours | | | | | +38% |
| One Redis PUBLISH per post | Ours | | | | | +4% |
| Retry the write lock every 100 µs, not 1 ms | Ours | | | | | +20% |
| Route `/assets` and `/cable` by prefix | Ours | +5–8% on small routes | | | | |
| Message versions as an ETag part | Rust | +7% | +8% | | | |

Before this pass, the move from the first Sinatra checkpoint (room 1,316) to 2,572 mixed turning on
YJIT with cached gzip runs and in-memory static files. Those weren't measured separately.

## Rage

A rewrite on Rage (the Iodine server) and Sequel. It shares view code with Sinatra, so the two
compare as frameworks and data layers.

**Architecture:** Rage controllers on Iodine's C HTTP server; Sequel over SQLite with every query
a named prepared statement; Action Cable as a custom protocol on Rage::Cable, delivered by
Iodine's pub/sub in C.

**What made it fast**
- Run Sequel prepared statements by name through `Database#execute`: post +24%, room +17%.
- The same byte-offset split, per-segment gzip and whole-body gzip-by-ETag as Sinatra. Room and
  search +44% from the segment gzip alone.
- A `PRAGMA data_version` read cache: +26–47% on every read route.
- Kept finished responses: sidebar 3.4×, messages 1.9×, room 3.0×, search 2.5×.
- Cheaper posting: build the new message's view from the request's own data: +12.5%.
- A public-response cache, so avatars are 8.8× faster.
- Iodine's C layer makes tiny responses and cable fan-out about 2× Sinatra's.

**Dropped:** moving WAL checkpoints off the request path did nothing in Rage. Its commit cost is
the WAL writes themselves.

**Effect of each change.** Same method, with each change A/B tested against the commit before it.

| Change | Source | Room | Messages | Sidebar | Search | Post |
|---|---|---:|---:|---:|---:|---:|
| Sequel prepared statements run by name | Rust (prepared statements everywhere) | +17% | — | +23% | — | +24% |
| Split pages by byte offset | Ours (bug in shared code) | +23% | +2% | — | +10% | — |
| Keep each page segment's gzip | Rust | +44% | — | — | +44% | — |
| Keep a body's gzip by its ETag (`/up` +58%) | Rust, Elixir | | | +56% | | |
| Read cache (`PRAGMA data_version`) | Elixir | +26% | +34% | +39% | +47% | 0% |
| Keep the finished sidebar | Elixir | | | +240% | | |
| Keep finished messages pages by ETag | Elixir | | +90% | | | |
| ~~Keep finished room / search pages~~ | **Removed**: no precedent | +200% | | | +150% | |
| WAL checkpoints off the request path | Rust | | | | | −2% (dropped) |
| Build the new message from the request's own data | Ours | | | | | +13% |
| Public-response cache (avatars 8.8×, CSS +9%) | Rust, Thruster | | | | | |

## Where the ideas came from

Most of the second-pass work came from reading the history of DHH's Rust port and the Elixir
port's PR #5 ([basecamp/once-campfire-elixir#5](https://github.com/basecamp/once-campfire-elixir/pull/5)).
The core idea is the same in all three: once CSRF tokens are gone, pages are identical between
requests, so rendered output can be reused.

How far each one takes it:

- **Rust** renders every page on every request. It caches the message fragments already gzipped
  and splices them in without copying them. Its front-server cache only covers public responses
  such as avatars and assets.
- **Elixir** memoizes the room page's shell and the messages page's parts by their inputs and ETag,
  over a read cache. It still runs the lookups that build those keys on each request.
- **Ours** keeps the whole finished response, keyed by a database-wide write counter
  (`PRAGMA data_version`) plus the request's inputs. On a hit, no query, template or gzip runs at
  all. This goes further than both references. It's correct, because any write invalidates it.
  But it's the change the benchmark's write-free read routes reward most (see Caveats).

## Caveats

- **The read routes never see a write during the run.** The caches that Elixir also uses (sidebar,
  messages page per ETag, read cache) hit nearly every request. The Rust and Elixir numbers share
  this property. This mixed run loads the room page while another user posts into the same room
  (reads/sec at 16 clients, the median of 3 reps, each on a fresh seed):

  | Posts/sec in the background | 0 | 20 | 100 |
  |---|---:|---:|---:|
  | Rails (stock) | 228 | 214 | 194 |
  | Rails (optimized) | 537 | 430 | 208 |
  | Sinatra | 12,648 | 12,096 | 8,909 |
  | Rage | 10,074 | 9,309 | 6,697 |

  Sinatra and Rage keep about 70% of their read rate at 100 posts/sec. Optimized Rails falls to
  about stock's level.
- **Worker counts differ.** Optimized Rails, Sinatra and Rage each run 4 processes; stock Rails
  runs 3, its default.
- **Uploads:** Sinatra and Rage are about 2× slower than Rails (135 ms vs 67 ms), and that isn't
  fixed yet.
- **Audit.** Every finding from the independent audit (`notes/audit.md`) is fixed in all three apps,
  except a few minor nits that are listed in each app's notes.
- **Parity.** These are Playwright cells on the final images.

  | Seed | Sinatra | Rage | Rails (optimized) |
  |---|---|---|---|
  | default | 874 / 874 | 874 / 874 | 874 / 874 |
  | crowd | 25 / 25 | 25 / 25 | 25 / 25 (before the fix pass) |
  | custom_styles | 33 / 33 | 33 / 33 | 33 / 33 (before the fix pass) |
  | first_run | 16 / 16 | 16 / 16 | 16 / 16 (before the fix pass) |
  | restricted | 8 / 8 | 8 / 8 | 8 / 8 (before the fix pass) |
