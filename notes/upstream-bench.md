# Upstream benchmark on the Hetzner box (Oct 10, 2026)

This runs DHH's shared verification harness ([basecamp/once-campfire-verification](https://github.com/basecamp/once-campfire-verification)
`ec02deb`) on our Hetzner box. It compares upstream Rails at its measured commit, the Rust and C
ports, our Sinatra, Rage and Roda, and stock Rails as a baseline.

Every timed response passed the harness's route contracts: status, headers, the full decoded body,
and exact message ids. Every acknowledged write passed the exact database and full-text-index
audit. Errors and invalid responses were zero for every app in both profiles.

## Normal profile

Requests/sec at 16 clients, median of 3 alternating rounds, 8 s samples. The app runs on CPUs 4-7
and the load generator on 0-3. Raw ranges are in the result files.

| HTTP workload (requests/sec) | Rails (stock acef0c7) | Rails (upstream 0aa339d) | Sinatra | Rage | Roda | Rust | C |
|---|---:|---:|---:|---:|---:|---:|---:|
| Room page | 215 | 3,188 | 11,062 | 7,870 | 12,103 | 41,653 | 65,511 |
| Messages page | 370 | 3,094 | 15,921 | 23,400 | 18,694 | 40,423 | 64,131 |
| Sidebar | 468 | 3,397 | 21,947 | 32,880 | 26,326 | 47,784 | 67,115 |
| Search | 368 | 3,307 | 14,091 | 16,311 | 15,738 | 46,485 | 67,818 |
| Post a message | 233 | 281 | 1,930 | 2,013 | 1,803 | 4,798 | 4,659 |

## Mixed profile

The harness's cache-churn profile: 16 readers plus one writer posting to another room, capped at
10 messages/sec. Read requests/sec, median of 3 rounds.

| Mixed workload (read requests/sec) | Rails (upstream) | Sinatra | Rage | Roda | Rust | C |
|---|---:|---:|---:|---:|---:|---:|
| Room page | 1,472 | 10,328 | 9,810 | 11,726 | 40,118 | 60,587 |
| Messages page | 1,772 | 14,659 | 23,237 | 17,988 | 37,923 | 59,791 |
| Sidebar | 2,739 | 21,287 | 31,796 | 25,419 | 47,424 | 66,475 |
| Search | 2,305 | 14,464 | 16,017 | 15,354 | 45,592 | 65,336 |

Every app made all 1,200 timed writes except upstream Rails, which made 1,169 because its posting
sometimes fell behind the 10/s cap.

## The hardware factor

Our box's result as a share of DHH's published figure (normal profile):

| Route | Rails (upstream) | Rust | C |
|---|---:|---:|---:|
| Room page | 0.78 | 0.39 | 0.48 |
| Messages page | 0.75 | 0.39 | 0.44 |
| Sidebar | 0.78 | 0.40 | 0.44 |
| Search | 0.77 | 0.38 | 0.45 |
| Post a message | 0.85 | 0.60 | 0.62 |

Stock Rails runs at 85–89% of its published reads, close to upstream Rails' 75–78%. Rust and C run
at only 38–48% of theirs. The faster an implementation is per request, the more this 65 W Ryzen 7
PRO 8700GE falls behind DHH's Ryzen AI MAX+ 395. So comparisons between the two machines overstate
the Ruby–Rust gap by about 2×. The Oct 7 Rust build showed the same effect at 0.6; the current Rust
(6dae2fd) is faster, which widens it.

## Our Ruby apps on the same box

Share of upstream Rails / share of Rust (normal profile):

| Route | Sinatra | Rage | Roda |
|---|---|---|---|
| Room page | 3.5× / 27% | 2.5× / 19% | 3.8× / 29% |
| Messages page | 5.1× / 39% | 7.6× / 58% | 6.0× / 46% |
| Sidebar | 6.5× / 46% | 9.7× / 69% | 7.8× / 55% |
| Search | 4.3× / 30% | 4.9× / 35% | 4.8× / 34% |
| Post a message | 6.9× / 40% | 7.2× / 42% | 6.4× / 38% |

Under writes the gap to upstream Rails grows. Mixed room reads are 7–8× upstream Rails, because a
Rails page miss is far more expensive to render.

Caveat: Sinatra, Rage and Roda run without whole-response caching (removed in the precedent audit),
while upstream Rails, Rust and C all have it. That's step 2 of the plan.

## Images (all labelled with their source commit)

| App | Image | Source |
|---|---|---|
| Stock Rails | `campfire-reference:app` | `acef0c7` (built Oct 5) |
| Upstream Rails | `once-campfire:app-0aa339d` | basecamp/once-campfire `0aa339d`, upstream Dockerfile |
| Rust | `campfire-rust:main-6dae2fd` | basecamp/once-campfire-rust `6dae2fd` |
| C | `once-campfire-c:main-873a51f` | basecamp/once-campfire-c `873a51f`; `make bench` built in a Fedora container, then its `bench/image/Dockerfile.c` |
| Sinatra | `campfire-sinatra:app` | `fb24b48` (HEAD `efdfc56` changes only the README) |
| Rage | `campfire-rage:app` | `623fb2d` (HEAD `8fd0ee2` changes only the README) |
| Roda | `campfire-roda:app` | `44c135c` (HEAD `6f3cc4e` changes only the README) |

The fixture was built by the harness's own `bin/seed` from the pinned Rails `90b3300` (seed SHA in
the summary files).

## Differences from DHH's method

- **CPUs:** app on 4-7 and load generator on 0-3 here, against 8-11 and 12-15 on DHH's machine.
  Both use four physical cores each with SMT siblings idle; the box's other load was stopped.
- **Upstream Rails topology:** the published one: `WEB_CONCURRENCY=4`, `RAILS_MAX_THREADS=1`, a
  64 MB response cache (default).
- **Our Ruby apps:** `WEB_CONCURRENCY=4`, one process per core. Stock Rails uses the harness
  default (3 workers × 5 threads). Rust and C use their defaults, as in DHH's runs.
- **Harness changes,** each marked `HETZNER CHANGE` in `bench/compare.rb` and
  `bench/contracts.rb`:
  - **New adapters:** `reference`, `sinatra`, `rage` and `roda`.
  - **Seed ownership:** the seed copy is chowned to uid 1000, because this box runs as root.
  - **Redis:** an extra mount gives the Rails-style apps a `redis.conf` on port 6390, since the
    host already uses 6379. They get `REDIS_URL` to match.
  - **Search ordering:** stock Rails, Sinatra, Rage and Roda keep stock's search order (the last
    100 matches by `created_at`), so their expected search ids use that ORDER BY. Upstream changed
    it to index rowid in `edaab3e`. On this fixture all 13 "coffee" matches have distinct times,
    and the contract still checks exact ids.
- **Tools:** `ffprobe` (avatar validation; avatars weren't in the routes run) is a wrapper that
  runs it from the reference image. The load generator was built from the harness's locked
  sources with cargo 1.98.0.
- **The `response_cache_mb: 64` label** that the harness metadata prints for every app is only a
  label. Stock Rails, Sinatra, Rage and Roda don't read `CAMPFIRE_RESPONSE_CACHE_MB`.
- **tmpfs:** the per-run databases were on a 12 GB tmpfs, as in DHH's runs.

## Files

- Raw results: `results/hetzner/upstream-2026-10-10/normal-20261010-165758/`,
  `mixed-20261010-171750/`, and `runs.log`. On the box under
  `/opt/campfire-perf/verify/once-campfire-verification/tmp/bench/results/`.
- Harness, scripts and app checkouts on the box: `/opt/campfire-perf/verify/`. Scripts:
  - `run_bench.sh preflight|normal|mixed APPS`
  - `run_all.sh`
  - `build_all.sh`, `build_c.sh`, `build_seed.sh`
  - `redis-6390.conf`, `ffprobe`
- Images are left in place for the next steps.
