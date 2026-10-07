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
  MAX+ 395, an Apple M3), so they don't compare column for column with these.

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
