# Campfire benchmarks: Rails, Sinatra and Rage

These are three Ruby takes on [once-campfire](https://github.com/basecamp/once-campfire). All three
were measured with DHH's harness from
[once-campfire-rust](https://github.com/basecamp/once-campfire-rust) and checked with its Playwright
parity harness.

| Implementation | Code |
|---|---|
| Rails, optimized | [jpcamara/once-campfire, branch `perf`](https://github.com/jpcamara/once-campfire/tree/perf) |
| Sinatra + Falcon | [jpcamara/once-campfire-sinatra](https://github.com/jpcamara/once-campfire-sinatra) |
| Rage + Sequel | [jpcamara/once-campfire-rage](https://github.com/jpcamara/once-campfire-rage) |

## Final numbers

The final run was on Oct 7, 2026, with DHH's `bench/run`, on a Hetzner AMD Ryzen 7 PRO 8700GE.
Each app gets four hardware threads, with the load generator on four others. YJIT and jemalloc are
on. Each number is the median of 3 runs, rotating the app order, and all four apps ran together.
There were 0 errors.

| HTTP workload (requests/sec, 16 clients) | Rails (stock) | Rails (optimized) | Sinatra | Rage |
|---|---:|---:|---:|---:|
| Room page | 225 | 538 | 12,849 | 10,127 |
| Messages page | 364 | 2,003 | 19,729 | 24,569 |
| Sidebar | 482 | 3,578 | 23,016 | 34,134 |
| Search | 378 | 872 | 15,503 | 16,837 |
| Post a message | 198 | 258 | 3,302 | 1,848 |
| Avatar | 62,491 | 62,420 | 73,935 | 165,748 |

| Other | Rails (stock) | Rails (optimized) | Sinatra | Rage |
|---|---:|---:|---:|---:|
| Action Cable, 1,000 clients: p50 delivery | 42.8 ms | 40.1 ms | 9.3 ms | 5.0 ms |
| Action Cable, 1,000 clients: saturated delivery | 13 msg/s | 12 msg/s | 103 msg/s | 194 msg/s |
| Upload + thumbnail (505 KB) | 67 ms | 66 ms | 135 ms | 134 ms |
| Idle memory (anon) | 284 MB | 613 MB | 200 MB | 170 MB |
| Cold start | 3.6 s | 5.9 s | 1.5 s | 1.6 s |

In every Action Cable run, every client got every message.

Notes on the second table:

- **Uploads:** Sinatra and Rage are about 2× slower than Rails, and that isn't fixed yet.
- **Idle memory:** optimized Rails uses more because it runs 4 Falcon processes against stock's 3
  Puma workers, plus its per-process caches.

**Room-page reads while posts arrive.** The read routes above never see a write. This run shows what
the caches do under real traffic: reads/sec at 16 clients, while another user posts into the same
room at a steady rate. It's the median of 3 reps, each on a fresh seed. Every post succeeded at the
offered rate.

| Posts/sec in the background | 0 | 20 | 100 | Post p50 at 100/s |
|---|---:|---:|---:|---:|
| Rails (stock) | 228 | 214 | 194 | 9.9 ms |
| Rails (optimized) | 537 | 430 | 208 | 25.6 ms |
| Sinatra | 12,648 | 12,096 | 8,909 | 2.3 ms |
| Rage | 10,074 | 9,309 | 6,697 | 3.2 ms |

At 100 posts/sec, Sinatra and Rage keep about 70% of their read rate. Optimized Rails falls to
about stock's level, because each write invalidates the caches it depends on.

## Rust on the same box

DHH's Rust port at ccece30, the commit whose README carries his published table, built with its
pinned reference (90b3300). It ran with all four Ruby apps in one run on Oct 7: 3 reps, rotating
order, every suite, 0 errors. It's one process, as `bench/run` runs it.

| HTTP workload (requests/sec, 16 clients) | Rails (stock) | Rails (optimized) | Sinatra | Rage | Rust |
|---|---:|---:|---:|---:|---:|
| Room page | 225 | 551 | 12,861 | 10,127 | 21,229 |
| Messages page | 360 | 1,984 | 19,729 | 24,638 | 23,565 |
| Sidebar | 480 | 3,562 | 22,936 | 32,975 | 20,828 |
| Search | 382 | 863 | 15,700 | 16,910 | 21,276 |
| Post a message | 198 | 261 | 3,195 | 1,833 | 4,153 |
| Avatar | 61,687 | 62,178 | 72,081 | 181,576 | 196,297 |

| Other | Rails (stock) | Rails (optimized) | Sinatra | Rage | Rust |
|---|---:|---:|---:|---:|---:|
| Action Cable, 1,000 clients: p50 delivery | 44.6 ms | 40.9 ms | 9.0 ms | 5.0 ms | 4.3 ms |
| Action Cable, 1,000 clients: saturated delivery | 11 msg/s | 12 msg/s | 106 msg/s | 196 msg/s | 378 msg/s |
| Upload + thumbnail (505 KB) | 72 ms | 64 ms | 135 ms | 59 ms | 34 ms |
| Idle memory (anon) | 282 MB | 617 MB | 201 MB | 170 MB | 13 MB |

Rage's upload time is noisy between runs: 134 ms in the earlier final run, 59 ms here. Sinatra's
was 135 ms both times.

**Room-page reads while posts arrive** (same method as above):

| Posts/sec in the background | 0 | 20 | 100 | Post p50 at 100/s |
|---|---:|---:|---:|---:|
| Rust | 20,968 | 20,526 | 19,156 | 2.2 ms |

Rust renders every page on every request, so writes barely affect it: it keeps 91% of its read rate
at 100 posts/sec.

**This box against DHH's machine.** These are DHH's published numbers on a Ryzen AI MAX+ 395,
against the same commits run here:

| Route | Rails, DHH | Rails, here | Ratio | Rust, DHH | Rust, here | Ratio |
|---|---:|---:|---:|---:|---:|---:|
| Room page | 241 | 225 | 0.93 | 36,260 | 21,229 | 0.59 |
| Messages page | 413 | 360 | 0.87 | 40,872 | 23,565 | 0.58 |
| Sidebar | 552 | 480 | 0.87 | 34,672 | 20,828 | 0.60 |
| Search | 435 | 382 | 0.88 | 33,299 | 21,276 | 0.64 |
| Post a message | 273 | 198 | 0.73 | 6,896 | 4,153 | 0.60 |

Rust runs at about 60% of DHH's numbers here. Stock Rails runs at about 87–93% on reads.
Rails' reads lose less on this box than Rust's do. One guess is that Rust's per-request time is
closer to the raw limits of the CPU and memory, so a faster core helps it more. We haven't
measured that.

## Caching

The rule: only cache what the Rust or Elixir ports cache, checked against their source.

**What the Rust port caches** (from its source):

| Cache | What it holds | Rust source |
|---|---|---|
| Message fragments | Rails' own `cache message do` fragments, in memory, bounded by bytes | `views/src/fragment_cache.rs` |
| Compressed pieces | Each fragment's deflate block, the text between fragments, and a whole body's gzip by digest | `kit/src/deflater/splice.rs` |
| Public responses | `Cache-Control: public` responses such as avatars and assets | `kit/src/front/cache.rs` |
| Prepared statements | 256 per connection | `db` crate |

Rust caches no query results and no pages, sidebars or page shells. It renders every page on every
request.

**What our apps cache beyond that.** All of it is Elixir-only. Each cell is the effect of that one
change in a per-step A/B:

| Cache (Elixir only) | Rails (optimized) | Sinatra | Rage |
|---|---|---|---|
| Read cache, cleared on `PRAGMA data_version` | +10–16% | +16–25% | +26–47% |
| Finished sidebar until its data changes | sidebar 3.3× | sidebar +61% | sidebar 3.4× |
| Messages page per ETag | messages 1.9× | not measured alone | messages 1.9× |
| Room and search shell, memoized by its inputs | none | not measured alone | not measured alone |
| Verified session signatures | none | room +12% | none |

Sinatra and Rage also memoize some small derived values (avatar tokens, signed ids, stream names,
initials); those have no reference precedent.

**Rust-level caching only.** `CAMPFIRE_CACHING=rust` in each app turns off every cache in the
second table, and the small memos, and keeps Rust's. It ran on the same harness, box and CPUs, on
images built from the commit that adds the switch: 3 reps, 0 errors. Each cell is full caching →
Rust-level caching only.

| Workload (req/s, 16 clients) | Rails (stock) | Rails (optimized) | Sinatra | Rage |
|---|---:|---:|---:|---:|
| Room page | 225 | 538 → 498 | 12,849 → 4,812 | 10,127 → 4,752 |
| Messages page | 364 | 2,003 → 902 | 19,729 → 7,637 | 24,569 → 9,402 |
| Sidebar | 482 | 3,578 → 824 | 23,016 → 6,365 | 34,134 → 6,618 |
| Search | 378 | 872 → 767 | 15,503 → 7,442 | 16,837 → 7,536 |
| Post a message | 198 | 258 → 268 | 3,302 → 3,165 | 1,848 → 1,780 |

Stock Rails is from the full run; in the Rust-level run it measured 221 / 365 / 467 / 368 / 196.

The mixed read/write run in both modes (3 reps, fresh seed each):

| Room reads/sec while posts arrive at | 0/s | 20/s | 100/s |
|---|---:|---:|---:|
| Rails (stock) | 228 | 214 | 194 |
| Rails (optimized), full caching | 537 | 430 | 208 |
| Rails (optimized), Rust-level caching only | 504 | 416 | 208 |
| Sinatra, full caching | 12,648 | 12,096 | 8,909 |
| Sinatra, Rust-level caching only | 4,763 | 4,634 | 3,741 |
| Rage, full caching | 10,074 | 9,309 | 6,697 |
| Rage, Rust-level caching only | 4,763 | 4,401 | 3,164 |

With Rust-level caching only, Sinatra and Rage still serve 13–26× stock Rails on reads, and keep
66–79% of their room-page rate at 100 posts/s. Optimized Rails stays about 2× stock on room, messages
and search without the Elixir-only caches; its sidebar and messages-page gains come mostly from them.

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
removed. The "Removed" rows below show what it was worth.

## Where the gains come from

Each change was A/B tested against the commit before it: requests/sec at 16 clients, median of 3–5
alternating reps, with a fresh seed each time. Every step had its own baseline, so the percentages
don't multiply exactly into the totals.

**Source** says where each idea came from. **Ours** means it has no reference precedent; those
changes are internal, invisible from outside, and mostly bug fixes. A dash means no notable change
on that route.

### Rails (optimized)

| Change | Source | Room | Messages | Sidebar | Search | Post |
|---|---|---:|---:|---:|---:|---:|
| No `Rack::Deflater` (Thruster gzips), Redis `compress: false`, no `Rack::ETag`, 4 workers | Ours (config) | +56% | +52% | +19% | +31% | +19% |
| Puma → Falcon | Ours | +1% | +3% | +10% | +12% | +1% |
| Skip static-file disk checks; tags once per process; `Current.account` once | Ours | +10% | — | +14% | +14% | — |
| Per-process copy of versioned fragments; cache versions without a DB checkout | Ours | +13% | +20% | +6% | +8% | — |
| Boost forms built as strings | Ours | — | +2% | — | — | +8% |
| `Sec-Fetch-Site` instead of CSRF tokens | Rust | +14% | +16% | — | +9% | — |
| Keep each page's gzip by digest | Rust, Elixir | +7% | +20% | +7% | — | — |
| Read cache (`PRAGMA data_version`) | Elixir | — | +10% | +16% | +14% | — |
| Keep the finished sidebar | Elixir | | | +227% | | |
| Cookies only when they change | Rust | +17–23% on every read route | | | | |
| Messages page kept per ETag (vs. no keeping) | Elixir | | +86% | | | |
| ~~Keep finished room / search pages~~ | **Removed**: no precedent | (+352%) | | | (+254%) | |
| Push job query fixes | Ours | | | | | +1% |
| Restore `Rack::Deflater` (needed for parity) | — | −1–3% | | | | |

Tried and dropped: PostgreSQL (slower when it shares the same 4 CPUs), one transaction per post,
and in-process jobs (−16% on post).

### Sinatra

| Change | Source | Room | Messages | Sidebar | Search | Post |
|---|---|---:|---:|---:|---:|---:|
| Split pages by byte offset | Ours (bug in our code) | +18% | — | — | +7% | — |
| Keep each page segment's deflate block | Rust | +37% | — | — | +34% | — |
| Read cache (`PRAGMA data_version`) | Elixir | +16% | +21% | +16% | +25% | — |
| Keep the finished sidebar | Elixir | | | +61% | | |
| Fix: `config.ru` rebuilt the Rack stack per request | Bug fix | | | +114% | | |
| ~~Keep finished room / messages / search~~ | **Removed**: no precedent | (−43% when removed) | (−19%) | | (−30%) | |
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
| Public-response cache (avatars 16.4k → 82.6k) | Rust, Thruster | | | | | |

### Rage

| Change | Source | Room | Messages | Sidebar | Search | Post |
|---|---|---:|---:|---:|---:|---:|
| Sequel prepared statements run by name | Rust | +17% | — | +23% | — | +24% |
| Split pages by byte offset | Ours (bug in shared code) | +23% | +2% | — | +10% | — |
| Keep each page segment's gzip | Rust | +44% | — | — | +44% | — |
| Keep a body's gzip by its ETag | Rust, Elixir | | | +56% | | |
| Read cache (`PRAGMA data_version`) | Elixir | +26% | +34% | +39% | +47% | 0% |
| Keep the finished sidebar | Elixir | | | +240% | | |
| Keep finished messages pages by ETag | Elixir | | +90% | | | |
| ~~Keep finished room / search pages~~ | **Removed**: no precedent | (+130%) | | | (+130%) | |
| Room / search shell memoized, messages spliced per request | Elixir | (in the above) | | | | |
| Audit fixes, mostly random-token page markers (cause not isolated) | — | +26% | — | −8% | +34% | — |
| Build the new message from the request's own data | Ours | | | | | +13% |
| Public-response cache (avatars 8.8×) | Rust, Thruster | | | | | |

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
| Rails (optimized) | done | default 874/874 |
| Rage | done (30/30 verified from outside) | every seed: 874, 25, 33, 16, 8 of 8 |
| Sinatra | done | every seed: 874, 25, 33, 16, 8 of 8 |

## What's here

- `notes/what-made-them-fast.md`: the longer write-up of every change.
- `notes/audit.md`: the independent audit.
- `notes/{rails-opt,sinatra,rage}.md`: working notes for each implementation.
- `notes/elixir-rust-optimizations.md`: an analysis of the Rust port's history and Elixir's PR #5.
- `bench/`: the changed copy of the harness's `bench/run` (each change is marked `HETZNER CHANGE`),
  a probe script, and the PostgreSQL experiment.
- `tools/`: profiling, A/B and page-diff scripts. Set `BOX` / `BOX_IP` for your own machine.
- `results/hetzner/`: raw result JSONs and parity reports.
