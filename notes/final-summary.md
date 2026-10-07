# Campfire: Rails vs Sinatra vs Rage — final status (Oct 7, 2026)

Status: **parity reruns done; final benchmark on hold.** The coordinator held the final 3-app bench and
the mixed workload until JP decides on the independent audit's findings (`notes/audit.md`, not
reconciled here). The benchmark numbers below are the last measured ones, not a final run on the
images listed here.

## Images (all verified)

Each image's app files were checked against its git HEAD by sha256, path by path.

| App | Source commit | App image | Parity candidate image | Check |
|---|---|---|---|---|
| Sinatra + Falcon | 75f85be | campfire-sinatra:app 46ecf4801036 | 95df7ffe71eb | 116/116 tracked files identical |
| Rage + Sequel | 4e6b2af | campfire-rage:app 473bf7e81bc0 | f0a828c360d6 | 166/166 identical |
| Rails, optimized | b868f70 | campfire-reference:rails-opt f76aaed2a853 | 018c98db66af | 632 identical; 118 Docker-ignored files absent (test/, .github/, README…); the candidate's resque-pool.yml is the harness patch the reference parity image also gets |

The images don't carry an OCI label with the commit. Add one (and record `git archive HEAD | sha256sum`)
when rebuilding for the final bench.

## Parity (Playwright harness, reference vs candidate, frozen clock)

Cells: pass / fail / error / allowed.

| Seed (states) | Sinatra | Rage | Rails, optimized |
|---|---|---|---|
| default (184) | 874 / 0 / 0 / 0 | 873 / 0 / 0 / 1 | 874 / 0 / 0 / 0 (round r3, same image) |
| crowd (7) | 25 / 0 / 0 / 0 | 25 / 0 / 0 / 0 | 25 / 0 / 0 / 0 |
| custom_styles (9) | 33 / 0 / 0 / 0 | 32 / 1 / 0 / 0 | 33 / 0 / 0 / 0 |
| first_run (4) | 0 / 0 / 16 / 0 | 0 / 0 / 16 / 0 | 16 / 0 / 0 / 0 |
| restricted (2) | 8 / 0 / 0 / 0 | 8 / 0 / 0 / 0 | 8 / 0 / 0 / 0 |

Failures and errors:
- **first_run, Sinatra and Rage (16 errors each):** `/first_run` returns 500 on a fresh install. There
  is no account row yet. The shared layout helper `View#account_logo_path` (lib/campfire/view.rb:72)
  calls `account.updated_at` on nil. A new install can't be set up on either app. Not fixed.
- **pwa/manifest/custom_styles, Rage (1 fail, server layer):** Rage's manifest JSON-escapes the custom
  logo URL, where Rails HTML-escapes it (`&amp;`). The Rust port documents that same difference, but the
  allowlist covers only the default-seed manifest state. Sinatra matched Rails in 9825d44; Rage doesn't
  have that commit. The same cause is the 1 allowed cell on Rage's default seed.
- **Rage's earlier 10 network-idle errors are gone** (fix-network-idle merged).

Per-app details are in the "Final parity" sections of notes/sinatra.md, rage.md and rails-opt.md.
Summaries and reports are in results/hetzner/final-20261007-parity/.

## Benchmark: last measured numbers (not final)

Requests/sec at 16 clients, median of 3, bench/run-hetzner. These are from earlier image builds:
- **Sinatra:** the run labeled 3591f56. Per the audit, the box images were built before 9825d44/3591f56.
- **Rage:** the run labeled 3ce184c, but that image was built before that commit.
- **Rails:** this run used f76aaed2a853, the verified b868f70 image.

| | Room | Messages | Sidebar | Search | Post | Avatar | Cable p50 @1000 | Idle memory |
|---|---|---|---|---|---|---|---|---|
| Sinatra | 23,608 | 26,042 | 25,245 | 23,867 | 3,398 | 82,425 | 9.1 ms | 199 MB anon |
| Rage | 18,590 | 24,788 | 33,067 | 28,688 | 1,784 | 181,609 | 4.9 ms | ~165 MB |
| Rails, optimized | 2,887 | 2,932 | 3,709 | 3,631 | 268 | 61,298 | 39.1 ms | not measured this pass |
| DHH's Rails (README, his machine) | 241 | 413 | 552 | 435 | 273 | | | |
| Rust ccece30 (Elixir PR #5, Apple M3, Docker Desktop) | 26,796 | 28,335 | 27,538 | 25,488 | 6,101 | | | |
| Elixir PR #5 round 4 (M3) | 17,237 | 25,238 | 32,121 | 26,790 | 1,995 | | | |
| Rust 1ea6d6f (DHH's README, Ryzen AI MAX+ 395) | 36,260 | 40,872 | 34,672 | 33,299 | 6,896 | | | |

### Mixed workload (smoke test only)

`tools/mixed.sh` + `tools/paced_poster.py`: david reads the watercooler room page at 16 clients while
jason posts into that same room at a steady, open-loop rate. One rep, 3-second reads, final images.
This checked that the method works. It is not a result. The full run (3 alternating reps, 20-second
reads, fresh seed per cell) is queued in the scripts but held.

| App | Reads, 0 posts/s | Reads, 20 posts/s | Reads, 100 posts/s | Post p50 at 100/s |
|---|---|---|---|---|
| Sinatra | 22,820 | 18,673 | 15,694 | 2.1 ms |
| Rage | 18,631 | 17,176 | 11,682 | 3.0 ms |
| Rails, optimized | 2,586 | 1,089 | 188 | 16.3 ms |

All posts were accepted (200) at the offered rate. There were no read errors.

## Method and caveats

- **Same harness, hardware and settings for every app:**
  - DHH's bench/run-hetzner (a minimally patched bench/run, HETZNER CHANGE markers) and bench/loadgen.
  - The same Hetzner box: Ryzen 7 PRO 8700GE, app pinned to CPUs 4-7, loadgen to 0-3.
  - 4 server processes, YJIT on (verified inside the running workers), jemalloc.
  - The same seed, copied fresh for each app and rep. Rotating app order.
- **Cross-hardware caveat:** the published Rust and Elixir numbers come from faster per-core machines
  (Apple M3 under Docker Desktop; DHH's Ryzen AI MAX+ 395). Compare within a row group, not across
  machines. Elixir also gzips at level 1.
- **The benchmark's read routes run with no interleaved writes:**
  - Each route is measured on its own, with no posting during it.
  - The "kept until any write" response caches therefore hit about 100% on the read routes, in Sinatra,
    Rage and optimized Rails alike.
  - The pure-read numbers are best-case numbers for those caches. The mixed workload above is the
    measure of their real-world effect.
  - The post route invalidates the caches on every request, and is measured on its own.
- **Divergences from Rails, per app, and the Rust README "Known differences" entry each maps to:**

| Divergence | Sinatra | Rage | Rails, optimized | Rust README entry |
|---|---|---|---|---|
| Sec-Fetch-Site/Origin check in place of CSRF tokens; no token fields | yes | yes | yes | CSRF |
| The csrf meta tag is still rendered, with a fixed random token per process that nothing checks (because the reference's file_uploader.js reads it) | yes | yes | no (tag removed, file_uploader.js overridden) | CSRF (Rust removes the tag and overrides the script instead) |
| Cookies written only on change (session_token on sign-in and hourly refresh, last_room on change) | yes | yes | yes | Cookies |
| In-process jobs in place of Resque | yes | yes | no (tried: posts −16%) | Jobs |
| ETags from cached parts/inputs; finished pages kept until any database write | yes | yes | yes | Caching |
| Manifest JSON-escapes the logo URL | no (matches Rails since 9825d44) | yes | no | JSON |
| Thruster-style public-response cache per worker process, so a repeat on another worker says `X-Cache: miss` where the reference says `hit` | yes | yes | no (Thruster in front) | none (Rust has one process and one cache) |
| WAL checkpoints in a separate process | yes | no | no | none (not visible in responses) |
| Iodine's transport: `content-length` + `connection: keep-alive` where Thruster chunks | – | yes | – | none (transport only) |
| `Date` from the real clock only when the process clock is faked (test harness) | – | yes | – | none (affects only faked-clock runs) |

  The independent audit (`notes/audit.md`) lists more security issues and undisclosed divergences in
  Sinatra and Rage. They are not reflected in this table.
