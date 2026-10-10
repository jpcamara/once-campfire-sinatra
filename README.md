# Campfire benchmarks: Rails, Sinatra, Rage and Roda

These are four Ruby takes on [once-campfire](https://github.com/basecamp/once-campfire). All four
were measured with DHH's harness from
[once-campfire-rust](https://github.com/basecamp/once-campfire-rust) and checked with its Playwright
parity harness.

| Implementation | Code |
|---|---|
| Rails, optimized | [jpcamara/once-campfire, branch `perf`](https://github.com/jpcamara/once-campfire/tree/perf) |
| Sinatra + Falcon | [jpcamara/once-campfire-sinatra](https://github.com/jpcamara/once-campfire-sinatra) |
| Rage + Sequel | [jpcamara/once-campfire-rage](https://github.com/jpcamara/once-campfire-rage) |
| Roda + Sequel (Falcon) | [jpcamara/once-campfire-roda](https://github.com/jpcamara/once-campfire-roda) |

## Latest: DHH's verification harness, with the finished-page cache (Oct 10)

Upstream Rails and the Rust port both added a cache of finished private pages, kept until the next
database commit: upstream Rails
[ac73267](https://github.com/basecamp/once-campfire/commit/ac73267) /
[0f5d0b2](https://github.com/basecamp/once-campfire/commit/0f5d0b2) /
[8d02540](https://github.com/basecamp/once-campfire/commit/8d02540), Rust
[d09811c](https://github.com/basecamp/once-campfire-rust/commit/d09811c), both following the C
port. Sinatra, Rage and Roda now do the same (`lib/campfire/page_cache.rb` in each). Auth, room
access and cookies still run on every request, and any commit from any process clears the cache.

This run used DHH's own verification harness
([basecamp/once-campfire-verification](https://github.com/basecamp/once-campfire-verification)
`ec02deb`) on the same Hetzner box. App on CPUs 4-7, load generator on 0-3, 3 rounds, 8-second
samples, upstream Rails `0aa339d` and Rust `6dae2fd` in the same session. Every response passed the
harness's route checks and every write passed its audit, with 0 errors or invalid responses. Raw
results are in `results/hetzner/pagecache-2026-10-10/`.

| HTTP workload (requests/sec, 16 clients) | Rails (upstream) | Sinatra | Rage | Roda | Rust |
|---|---:|---:|---:|---:|---:|
| Room page | 3,189 | 22,266 | 21,106 | 24,769 | 42,282 |
| Messages page | 3,206 | 23,808 | 28,381 | 27,073 | 40,615 |
| Sidebar | 3,568 | 22,403 | 31,245 | 26,254 | 48,314 |
| Search | 3,450 | 22,008 | 29,798 | 26,107 | 47,564 |
| Post a message | 282 | 1,973 | 1,985 | 1,823 | 4,792 |

Mixed profile: 16 readers plus one writer posting at up to 10 messages/sec. Upstream Rails
acknowledged 389–391 of its 400 writes per round; every other app made all 400.

| Read requests/sec | Rails (upstream) | Sinatra | Rage | Roda | Rust |
|---|---:|---:|---:|---:|---:|
| Room page | 1,545 | 20,703 | 20,501 | 23,242 | 39,564 |
| Messages page | 1,875 | 22,143 | 28,234 | 25,975 | 37,997 |
| Sidebar | 2,838 | 21,605 | 29,963 | 24,994 | 46,939 |
| Search | 2,580 | 22,410 | 29,955 | 24,818 | 46,151 |

Before this cache, the same harness on the same day gave room pages of 11,062 (Sinatra), 7,870
(Rage) and 12,103 (Roda). On this box the Ruby apps now read at about half of Rust's rate, and
6–9× upstream Rails.

**Checks for the cache, in each app:**
- Playwright passes every cell on every seed.
- Server HTML matches the reference on 128/128 pages, and all 24 write flows match.
- With the cache on and off, statuses are identical through foreign writes, a revoked membership,
  a banned user and a deleted session.
- Check mode found 0 mismatches.

The script is `tools/pagecache-check.sh`.

## Final numbers (Oct 8, DHH's `bench/run`)

The final run was on Oct 8, 2026, after the [precedent audit](notes/precedent-audit.md). It used DHH's
`bench/run` on a Hetzner AMD Ryzen 7 PRO 8700GE. Each app gets four hardware threads, with the load
generator on four others. YJIT and jemalloc are on. Each number is the median of 3 runs in rotating
order. All five apps ran together, including DHH's Rust port, and there were 0 errors.

| HTTP workload (requests/sec, 16 clients) | Rails (stock) | Rails (optimized) | Sinatra | Rage | Roda† | Rust |
|---|---:|---:|---:|---:|---:|---:|
| Room page | 221 | 529 | 11,349 | 10,094 | 12,431 | 21,155 |
| Messages page | 370 | 1,985 | 16,256 | 24,763 | 19,386 | 23,515 |
| Sidebar | 482 | 3,557 | 22,613 | 33,951 | 27,366 | 20,769 |
| Search | 381 | 862 | 14,523 | 16,900 | 16,294 | 21,361 |
| Post a message | 195 | 259 | 1,799 | 1,643 | 1,732 | 4,109 |
| Avatar | 61,938 | 62,671 | 72,664 | 178,292 | 75,871 | 196,428 |

| Other | Rails (stock) | Rails (optimized) | Sinatra | Rage | Roda† | Rust |
|---|---:|---:|---:|---:|---:|---:|
| Action Cable, 1,000 clients: p50 delivery | 44.1 ms | 41.1 ms | 8.2 ms | 5.0 ms | 7.9 ms | 4.4 ms |
| Action Cable, 1,000 clients: saturated delivery | 12 msg/s | 12 msg/s | 104 msg/s | 184 msg/s | 104 msg/s | 376 msg/s |
| Idle memory (anon) | 283 MB | 613 MB | 200 MB | 170 MB | 196 MB | 13 MB |
| Upload + thumbnail (505 KB), Oct 7 run | 72 ms | 64 ms | 135 ms | 59–134 ms | 131 ms (Oct 8) | 34 ms |
| Cold start, Oct 7 run | 3.6 s | 5.9 s | 1.5 s | 1.6 s | 1.4 s (Oct 8) | — |

In every Action Cable run, every client got every message.

† Roda was added after the final run. Its numbers come from its own run of 3, in rotating order, with
stock Rails, Sinatra, Rage and Rust in the same session, on the same box and code. In that run, the
other four apps measured within 3% of the table above on every route. See [Roda](#roda) below.

Notes:

- **The precedent audit's effect.** It reverted every optimization with no Rust or Elixir
  counterpart. That moved Sinatra the most, since most of those changes were on its post path:
  posting fell from 3,195 to 1,799, room 12% and messages 18%. Rage's posting fell from 1,833 to
  1,643. Optimized Rails and the read routes elsewhere didn't move.
- **Uploads and cold start** are from the Oct 7 run; the audit didn't touch those paths. Sinatra and
  Rage uploads are about 2× slower than Rails. Rage's upload time is noisy between runs.
- **Idle memory:** optimized Rails uses more because it runs 4 Falcon processes against stock's 3
  Puma workers, plus its per-process caches.

**Room-page reads while posts arrive.** The read routes above never see a write. This run shows what
the caches do under real traffic: reads/sec at 16 clients, while another user posts into the same
room at a steady rate. It's the median of 3 reps, each on a fresh seed. Every post succeeded at the
offered rate. Stock Rails and Rust are from the Oct 7 run; their code didn't change.

| Posts/sec in the background | 0 | 20 | 100 | Post p50 at 100/s |
|---|---:|---:|---:|---:|
| Rails (stock) | 228 | 214 | 194 | 9.9 ms |
| Rails (optimized) | 534 | 441 | 205 | 25.9 ms |
| Sinatra | 11,253 | 10,806 | 7,748 | 3.1 ms |
| Rage | 10,100 | 9,361 | 6,558 | 3.6 ms |
| Roda† | 12,282 | 11,124 | 7,686 | 3.2 ms |
| Rust | 20,968 | 20,526 | 19,156 | 2.2 ms |

At 100 posts/sec, Sinatra and Rage keep about 65–70% of their read rate, and Rust keeps 91%, since
it renders every page on every request. Optimized Rails falls to about stock's level, because each
write invalidates the caches it depends on.

## Rust on the same box

DHH's Rust port at ccece30, the commit whose README carries his published table, is built with its
pinned reference (90b3300). It runs as one process, as `bench/run` runs it. Its numbers are in the
tables above.

**This box against DHH's machine.** These are DHH's published numbers on a Ryzen AI MAX+ 395,
against the same commits run here:

| Route | Rails, DHH | Rails, here | Ratio | Rust, DHH | Rust, here | Ratio |
|---|---:|---:|---:|---:|---:|---:|
| Room page | 241 | 221 | 0.92 | 36,260 | 21,155 | 0.58 |
| Messages page | 413 | 370 | 0.90 | 40,872 | 23,515 | 0.58 |
| Sidebar | 552 | 482 | 0.87 | 34,672 | 20,769 | 0.60 |
| Search | 435 | 381 | 0.88 | 33,299 | 21,361 | 0.64 |
| Post a message | 273 | 195 | 0.71 | 6,896 | 4,109 | 0.60 |

Rust runs at about 60% of DHH's numbers here. Stock Rails runs at about 87–92% on reads. So comparing
our numbers with his table overstates the gap between Ruby and Rust by about 1.5×. One guess at why:
Rust's per-request time is closer to the raw limits of the CPU and memory, so a faster core helps it
more. We haven't measured that.

## Roda

[jpcamara/once-campfire-roda](https://github.com/jpcamara/once-campfire-roda): Roda + Sequel on
Falcon, from a snapshot of the Sinatra app. Every file is the same as Sinatra's except the web layer
(`lib/campfire/app.rb`) and the database layer (`lib/campfire/db.rb`). It got the precedent audit's
reverts too, so every optimization in it cites Rust or Elixir or fixes a bug of ours. The
classification is in [notes/roda.md](notes/roda.md).

Its own run (Oct 8; 3 runs in rotating order; image built from 44c135c; 0 errors), requests/sec at
16 clients:

| Workload | Rails (stock) | Sinatra | Rage | Roda | Rust |
|---|---:|---:|---:|---:|---:|
| Room page | 222 | 11,303 | 10,146 | 12,431 | 21,206 |
| Messages page | 362 | 16,197 | 24,784 | 19,386 | 23,634 |
| Sidebar | 467 | 22,533 | 33,989 | 27,366 | 20,652 |
| Search | 372 | 14,574 | 16,843 | 16,294 | 21,361 |
| Post a message | 197 | 1,851 | 1,639 | 1,732 | 4,122 |

- **Against Sinatra:** same server, same views. Roda + Sequel reads 10–21% faster than Sinatra + the
  sqlite3 gem on every page route, and posts 6% slower.
- **Rust-level caching only** (`CAMPFIRE_CACHING=rust`, 3 runs, HTTP suite): room 12,431 → 5,037,
  messages 19,386 → 8,413, sidebar 27,366 → 6,448, search 16,294 → 7,269, post 1,732 → 1,676.
- **Parity on the final image:** every seed passes with no allowed differences. That's default
  874/874, crowd 25/25, custom_styles 33/33, first_run 16/16 and restricted 8/8.
- **Other checks:** 64 server pages and 24 write flows match the reference, 28 of 28 security checks
  pass, and cache check mode found 0 mismatches.
- **A bug the Sinatra app still has:** a bot's form-encoded message answers 422 where Rails answers
  201. Roda found and fixed it (590cb1b). Rack::MethodOverride had already read the body.

## Caching

The rule: only cache what the Rust or Elixir ports cache, checked against their source. The
[precedent audit](notes/precedent-audit.md) lists every cache and optimization with its citation.

**What the Rust port caches** (from its source):

| Cache | What it holds | Rust source |
|---|---|---|
| Message fragments | Rails' own `cache message do` fragments, in memory, bounded by bytes | `views/src/fragment_cache.rs` |
| Compressed pieces | Each fragment's deflate block, the text between fragments, and a whole body's gzip by digest | `kit/src/deflater/splice.rs` |
| Public responses | `Cache-Control: public` responses such as avatars and assets | `kit/src/front/cache.rs` |
| Prepared statements | 256 per connection | `db` crate |

Rust caches no query results and no pages, sidebars or page shells. It renders every page on every
request.

**What our apps cache beyond that.** All of it comes from the Elixir port. Each cell is the effect of
that one change in a per-step A/B:

| Cache (Elixir only) | Elixir source | Rails (optimized) | Sinatra | Rage |
|---|---|---|---|---|
| Read cache, cleared on `PRAGMA data_version` | `db.ex` | +10–16% | +16–25% | +26–47% |
| Finished sidebar until its data changes | `sidebar.ex` | sidebar 3.3× | sidebar +61% | sidebar 3.4× |
| Messages page per ETag | `messages.ex` | messages 1.9× | not measured alone | messages 1.9× |
| Room and search shell, memoized by its inputs | `room_page.ex`, `searches.ex` | none | not measured alone | not measured alone |
| Verified session_token cookie | `auth.ex` | none | room +12% | none |
| Avatar tokens | `mentions.ex` | none | not measured alone | not measured alone |

**Rust-level caching only.** `CAMPFIRE_CACHING=rust` in each app turns off every cache in the second
table and keeps Rust's. It ran on Oct 8 with the same harness, box, CPUs and images as the final run:
3 runs in rotating order, HTTP suite, 0 errors. Each cell is full caching → Rust-level caching only.

| Workload (req/s, 16 clients) | Rails (stock) | Rails (optimized) | Sinatra | Rage | Rust |
|---|---:|---:|---:|---:|---:|
| Room page | 221 | 529 → 516 | 11,349 → 4,911 | 10,094 → 4,743 | 21,155 |
| Messages page | 370 | 1,985 → 902 | 16,256 → 7,798 | 24,763 → 9,486 | 23,515 |
| Sidebar | 482 | 3,557 → 843 | 22,613 → 6,403 | 33,951 → 6,475 | 20,769 |
| Search | 381 | 862 → 762 | 14,523 → 7,641 | 16,900 → 7,558 | 21,361 |
| Post a message | 195 | 259 → 273 | 1,799 → 1,817 | 1,643 → 1,608 | 4,109 |

The mixed read/write run in both modes (3 reps, fresh seed each):

| Room reads/sec while posts arrive at | 0/s | 20/s | 100/s |
|---|---:|---:|---:|
| Rails (stock) | 228 | 214 | 194 |
| Rails (optimized), full caching | 534 | 441 | 205 |
| Rails (optimized), Rust-level caching only | 508 | 419 | 205 |
| Sinatra, full caching | 11,253 | 10,806 | 7,748 |
| Sinatra, Rust-level caching only | 4,782 | 4,710 | 3,711 |
| Rage, full caching | 10,100 | 9,361 | 6,558 |
| Rage, Rust-level caching only | 4,720 | 4,339 | 3,192 |
| Rust | 20,968 | 20,526 | 19,156 |

With only Rust-level caching, Sinatra and Rage read at 22–41% of Rust's rate and post at 39–44% of
it, while still serving 13–26× stock Rails on reads. Optimized Rails stays about 2× stock on room,
messages and search without the Elixir-only caches; its sidebar and messages-page gains come mostly
from them.

## The rules

**Parity.** Each app must match the Rails reference as a black box. That's checked with DHH's
Playwright harness (HTML, DOM, accessibility tree, assets, cable frames and screenshots on every
seed) and with server-HTML diffs. The only allowed differences are the ones the Rust port documents
in its README under "Known differences". The one that matters most: `Sec-Fetch-Site` replaces CSRF
tokens, so a page renders the same until its content changes.

**Caching.** We only use caching techniques that the Rust or Elixir ports actually use, checked
against their source:

- **Rust** renders every page on every request. It caches message fragments already gzipped and
  splices them in. Its front-server cache only covers public responses.
- **Elixir**
  ([PR #5](https://github.com/basecamp/once-campfire-elixir/pull/5)) adds a read cache that's
  cleared when a table is written. It also memoizes the room page's shell by its inputs, keeps
  messages-page parts per ETag, and keeps the finished sidebar until its tables change.

An earlier version of all three apps kept finished room and search pages whole. Neither reference
does that, and a benchmark that never interleaves writes with reads rewards it heavily. It's been
removed.

**Precedent.** Every performance change has to be a fix of our own bug, something the Rust port
does, or one of the Elixir caches above. The [precedent audit](notes/precedent-audit.md) classifies
each change with its citation and reverted the rest: whole-page keeping, Sinatra's plain-text fast
path, faster write-lock retries, batched publishes, building new messages from request data, and
several small memos.

## Where the gains come from

Each change was A/B tested against the commit before it: requests/sec at 16 clients, median of 3–5
alternating reps, with a fresh seed each time. Every step had its own baseline, so the percentages
don't multiply exactly into the totals.

**Source** says where each idea came from: a fix of our own bug or misconfiguration, the Rust port, or
the Elixir port's caches. The [precedent audit](notes/precedent-audit.md) reverted every change with
neither precedent; the "Reverted" tables show what each was worth. A dash means no notable change on
that route.

### Rails (optimized)

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

Tried and dropped: PostgreSQL (slower when it shares the same 4 CPUs), one transaction per post,
and in-process jobs (−16% on post).

### Sinatra

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

### Rage

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

Moving WAL checkpoints off the request path did nothing in Rage (−2%), so it was dropped: its
commit cost is the WAL writes themselves.

## Caveats

- **The read routes never see a write during the run.** The caches that Elixir also uses (sidebar,
  messages page per ETag, read cache) therefore hit nearly every request. The Rust and Elixir
  numbers share this property. The mixed read/write table above shows the effect of writes.
- **Worker counts differ.** Optimized Rails, Sinatra and Rage each run 4 processes; stock Rails runs
  3, its default.
- **Hardware.** The published Rust and Elixir numbers come from faster machines (DHH's Ryzen AI
  MAX+ 395, an Apple M3). Rust has also been run on this box; see "Rust on the same box". The
  Elixir port hasn't been run here.

## Security and parity status

An independent audit (`notes/audit.md`) reviewed every cache for cross-user exposure, and the
security of all three apps. It found no cache that could serve one user's data to another. It did
find real bugs in Sinatra and Rage: stored XSS through uploads, no Origin check on `/cable`, a bot
API forgery gap, and fragment-marker injection. It also found a few undisclosed differences from
Rails in all three.

| | Audit fixes | Playwright parity |
|---|---|---|
| Rails (optimized) | done | default 874/874; after the audit's revert, realtime and composer 150/150 |
| Rage | done (30/30 verified from outside) | every seed: 874, 25, 33, 16, 8 of 8; after the reverts, touched groups 408/408 |
| Sinatra | done | every seed: 874, 25, 33, 16, 8 of 8; after the reverts, touched groups 408/408 |

After the precedent audit's reverts, server HTML still matches the reference on every compared page
(Sinatra and Rage 128/128 fresh and cached, Rails 58/58), and all 24 write flows match.

## What's here

- `notes/what-made-them-fast.md`: the longer write-up of every change.
- `notes/audit.md`: the independent audit.
- `notes/precedent-audit.md`: every optimization, its class (bug fix / Rust / Elixir cache) and citation, and what was reverted.
- `notes/{rails-opt,sinatra,rage}.md`: working notes for each implementation.
- `notes/elixir-rust-optimizations.md`: an analysis of the Rust port's history and Elixir's PR #5.
- `bench/`: the changed copy of the harness's `bench/run` (each change is marked `HETZNER CHANGE`),
  a probe script, and the PostgreSQL experiment.
- `tools/`: profiling, A/B and page-diff scripts. Set `BOX` / `BOX_IP` for your own machine.
- `results/hetzner/`: raw result JSONs and parity reports.
