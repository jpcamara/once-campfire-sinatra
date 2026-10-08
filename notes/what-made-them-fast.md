# What made each Campfire implementation fast

Measured with DHH's harness (`bench/run` from once-campfire-rust) on a Hetzner Ryzen 7 PRO 8700GE.
Each app gets 4 hardware threads, the load generator gets 4 others, and there are 16 clients.
Results are requests/sec, median of 3 runs in rotating order, with YJIT and jemalloc on for every app.

| HTTP workload (requests/sec) | Rails (stock) | Rails (optimized) | Sinatra | Rage | Rust |
|---|---:|---:|---:|---:|---:|
| Room page | 221 | 529 | 11,349 | 10,094 | 21,155 |
| Messages page | 370 | 1,985 | 16,256 | 24,763 | 23,515 |
| Sidebar | 482 | 3,557 | 22,613 | 33,951 | 20,769 |
| Search | 381 | 862 | 14,523 | 16,900 | 21,361 |
| Post a message | 195 | 259 | 1,799 | 1,643 | 4,109 |

These are from the final run on Oct 8, 2026, after the [precedent audit](precedent-audit.md): all five
apps measured together, including DHH's Rust port, with 0 errors. Every optimization left is a fix of
our own bug, something the Rust port does, or a cache the Elixir port has. Everything else was
reverted, including whole-page caching of the room, search and messages pages. The per-change tables
below come from the A/B run for each step; the "Reverted" tables show what each reverted change was
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
- Keep the finished sidebar until the database changes (as the Elixir port does), and keep messages
  pages per ETag, with a check mode that re-renders each hit and compares. Room and search pages
  render on every request.
- Write cookies only when they change.
- Push job: no user query per subscription, and no mentions query when nobody is mentioned. (One
  badge count per user was reverted: Rust counts per subscription.)
- Bug fix: request bodies weren't rewindable under Falcon, which broke the bot API.

**Tried and dropped:** PostgreSQL (slower when it shares the same 4 CPUs), putting each post in
one transaction, and in-process jobs (posting was −16% because single-threaded Falcon processes
block on SQLite).

**Effect of each change.** Each step was A/B tested against the commit just before it (requests/sec
at 16 clients, median of 3–5 alternating reps). Every step had its own baseline, so the percentages
don't multiply into the totals exactly. A dash means no notable change on that route.

| Change | Source | Room | Messages | Sidebar | Search | Post |
|---|---|---:|---:|---:|---:|---:|
| No double compression (Thruster already gzips), Redis `compress: false`, no `Rack::ETag`, 4 workers | Config fix | +56% | +52% | +19% | +31% | +19% |
| Puma → Falcon (`isolation_level = :fiber`) | Config | +1% | +3% | +10% | +12% | +1% |
| Public files from an index, not disk probes; stylesheet tags once per process; account loaded once per page | Rust (`assets/src/serve.rs`, b93306d, `Layout::load`) | +10% | — | +14% | +14% | — |
| Fragment cache in process; cache versions computed from the row | Rust (`views/src/fragment_cache.rs`) | +13% | +20% | +6% | +8% | — |
| Quick boost forms as literal HTML | Rust (`templates/messages/_actions.html`) | — | +2% | — | — | +8% |
| `Sec-Fetch-Site` instead of CSRF tokens | Rust (b567772) | +14% | +16% | — | +9% | — |
| Keep each page's gzip by digest | Rust (2f755bf), Elixir | +7% | +20% | +7% | — | — |
| Read cache cleared on `PRAGMA data_version` | Elixir (`db.ex`) | — | +10% | +16% | +14% | — |
| Keep the finished sidebar until its data changes | Elixir (`sidebar.ex`) | | | +227% | | |
| Cookies only when they change | Rust (2947c64) | +17–23% on every read route | | | | |
| Messages page kept per ETag | Elixir (`messages.ex`) | | +86% | | | |
| Push job: no user query per subscription, no mentions query without mentions | Rust (`push_subscription.rs`) | | | | | +1% |
| Restore `Rack::Deflater` (needed for parity) | — | −1–3% | | | | |

**Reverted for lack of precedent:**

- Keeping finished room and search pages whole (room 2,944, search 3,697). Neither port does that.
- Counting each user's push badge once per push. Rust counts it per subscription.

## Sinatra

A rewrite on Sinatra and Falcon.

**Architecture:** the `sqlite3` gem used directly with a prepared-statement cache (no
ActiveRecord); ERB views ported to Erubi and compiled at boot; Action Cable implemented natively
over `async-websocket`, with Redis pub/sub between workers; jobs run in-process.

**What made it fast**
- Fixed our own bugs and misconfigurations. `config.ru` rebuilt the whole Rack stack on every
  request, the image ran in development mode, Falcon compressed a second time on top of the app, and
  pages were split by character offset (on UTF-8 pages, about 24% of the room page's CPU).
- What the Rust port does: message fragments spliced into the page with their deflate blocks already
  computed; each page segment's deflate block and a whole body's gzip kept; WAL checkpoints in their
  own process; static files from memory; `/assets` and `/cable` handled before routing; a cache for
  public responses such as avatars.
- The Elixir port's caches: a read cache cleared on `PRAGMA data_version`; the finished sidebar kept
  until its data changes; the messages page kept per ETag; the room and search shells memoized by
  their inputs; the verified session_token cookie remembered.

**Effect of each change.** Same method as the Rails table: an A/B against the commit before, at 16
clients.

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

Before this pass, the move from the first Sinatra checkpoint (room 1,316) to 2,572 mixed turning on
YJIT with cached gzip runs and in-memory static files. Those weren't measured separately.

## Rage

A rewrite on Rage (the Iodine server) and Sequel. It shares view code with Sinatra, so the two
compare as frameworks and data layers.

**Architecture:** Rage controllers on Iodine's C HTTP server; Sequel over SQLite with every query
a named prepared statement; Action Cable as a custom protocol on Rage::Cable, delivered by
Iodine's pub/sub in C.

**What made it fast**
- What the Rust port does: every query a named prepared statement (post +24%, room +17%); the same
  segment gzip and whole-body gzip as Sinatra (room and search +44% from the segment gzip alone); a
  public-response cache (avatars 8.8×).
- Fixed our own bugs: character-offset splitting, binary binds, file reads stalling the scheduler,
  and the bind-parameter limit.
- The Elixir port's caches: the read cache (+26–47% on every read route), the kept sidebar (3.4×),
  messages pages per ETag (1.9×), and the room and search shells.
- Iodine's C layer makes tiny responses and cable fan-out about 2× Sinatra's.

**Dropped:** moving WAL checkpoints off the request path did nothing in Rage. Its commit cost is
the WAL writes themselves.

**Effect of each change.** Same method, with each change A/B tested against the commit before it.

| Change | Source | Room | Messages | Sidebar | Search | Post |
|---|---|---:|---:|---:|---:|---:|
| Sequel prepared statements run by name | Rust (prepared statements everywhere) | +17% | — | +23% | — | +24% |
| Split pages by byte offset | Bug fix | +23% | +2% | — | +10% | — |
| Keep each page segment's gzip | Rust (2947c64) | +44% | — | — | +44% | — |
| Keep a body's gzip by its ETag | Rust (2f755bf), Elixir | | | +56% | | |
| Read cache cleared on `PRAGMA data_version` | Elixir (`db.ex`) | +26% | +34% | +39% | +47% | 0% |
| Keep the finished sidebar until its data changes | Elixir (`sidebar.ex`) | | | +240% | | |
| Keep finished messages pages by ETag | Elixir (`messages.ex`) | | +90% | | | |
| Room / search shell memoized, messages spliced per request | Elixir (`room_page.ex`, `searches.ex`) | | | | | |
| Audit fixes, mostly random-token page markers (cause not isolated) | — | +26% | — | −8% | +34% | — |
| Public-response cache (avatars 8.8×) | Rust (`front/cache.rs`), Thruster | | | | | |

**Reverted for lack of precedent.** Each was measured as a gain when it was added:

| Reverted change | Gain it had | Why |
|---|---|---|
| Keep finished room / search pages whole | about 2.3× on both | neither port keeps whole pages |
| Build a new message's view and push payload from the request | post +13% | Rust reads them back through its presenter |
| Memoized signed stream names and blob ids, initials SVGs | not measured alone | Rust generates each per use |

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
- **Ours** do what Rust does plus Elixir's caches, and nothing beyond them. Earlier versions kept the
  whole finished room, search and messages responses, which went further than both references and
  was the change the benchmark's write-free read routes rewarded most. That, and every other change
  without a Rust or Elixir counterpart, was reverted (see the [precedent audit](precedent-audit.md)).

## Caveats

- **The read routes never see a write during the run.** The caches that Elixir also uses (sidebar,
  messages page per ETag, read cache) hit nearly every request. The Rust and Elixir numbers share
  this property. This mixed run loads the room page while another user posts into the same room
  (reads/sec at 16 clients, the median of 3 reps, each on a fresh seed):

  | Posts/sec in the background | 0 | 20 | 100 |
  |---|---:|---:|---:|
  | Rails (stock), Oct 7 run | 228 | 214 | 194 |
  | Rails (optimized) | 534 | 441 | 205 |
  | Sinatra | 11,253 | 10,806 | 7,748 |
  | Rage | 10,100 | 9,361 | 6,558 |
  | Rust, Oct 7 run | 20,968 | 20,526 | 19,156 |

  Sinatra and Rage keep about 65–70% of their read rate at 100 posts/sec, and Rust keeps 91%.
  Optimized Rails falls to about stock's level.
- **Worker counts differ.** Optimized Rails, Sinatra and Rage each run 4 processes; stock Rails
  runs 3, its default.
- **Uploads:** Sinatra and Rage are about 2× slower than Rails (135 ms vs 67 ms), and that isn't
  fixed yet.
- **Audit.** Every finding from the independent audit (`notes/audit.md`) is fixed in all three apps,
  except a few minor nits that are listed in each app's notes.
- **Parity.** These are Playwright cells on the images before the precedent audit. After its
  reverts, the groups they touch passed again on the final images (Sinatra and Rage 408/408, Rails
  150/150), and server HTML and the write flows still match the reference.

  | Seed | Sinatra | Rage | Rails (optimized) |
  |---|---|---|---|
  | default | 874 / 874 | 874 / 874 | 874 / 874 |
  | crowd | 25 / 25 | 25 / 25 | 25 / 25 (before the fix pass) |
  | custom_styles | 33 / 33 | 33 / 33 | 33 / 33 (before the fix pass) |
  | first_run | 16 / 16 | 16 / 16 | 16 / 16 (before the fix pass) |
  | restricted | 8 / 8 | 8 / 8 | 8 / 8 (before the fix pass) |
