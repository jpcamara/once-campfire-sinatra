# Rails optimizations (apps/rails-opt, branch opt)

Pass 1 (Oct 5-6) kept byte-identity with the stock app; pass 2 (Oct 6, below) takes the Rust port's
documented divergences. Current state, per-route results and parity status are in pass 2.

Base: falcon-fixes (Falcon, 4 processes, no Rack::Deflater, no cache compression, no Rack::ETag), SQLite.
Measured on the Hetzner box, app CPUs 4-7, loadgen 0-3, c=16, 8 s per route, fresh seed per run,
median of alternating reps (tools/ab.sh). Parity: tools/pagediff.sh against the stock image
(campfire-reference:app): 27 pages, robots.txt, 404.html, 3 assets and a message post, CSRF tokens
and transfer tokens masked.

Profiling: rbspy in blocking mode on the puma-fixes image (rbspy can't see Falcon's fibers; same
Rails code). tools/profile.sh, tools/stacks.py.

| # | Change | room | messages | sidebar | search | post | Parity |
|---|---|---|---|---|---|---|---|
| 1-3 | Static file index, asset tags once, Current.account per request | 360 → 395 | 581 → 587 | 623 → 710 | 544 → 619 | 248 → 250 | identical |
| 4-5 | Fragment entries kept in process (FragmentCacheStore), cache_version without connection checkout | 400 → 452 | 586 → 704 | 704 → 743 | 621 → 668 | 245 → 252 | identical (58 responses incl. cached second pass) |
| 6 | Quick boost forms built as strings (token_tag kept) | 440 → 440 | 683 → 699 | – | – | 259 → 280 | identical |
| – | One transaction for post (FTS + unread inside) | – | – | – | – | 274 → 274 | not kept |

## Notes

- Commits 1-3 and 4-5 were each measured as a group (one A/B per group); the commit messages say so.
- Parity: byte-identical to the stock image (campfire-reference:app) on every check, after masking CSRF
  tokens, transfer tokens, message ids/timestamps and the room's loaded-at time. The post response is the
  fragment the broadcast rendered, so it also checks the broadcast HTML. The Playwright parity harness was
  not run: it builds the Rust candidate, and the byte diff is stricter than its screenshot comparison.
- FragmentCacheStore keeps only string (HTML) fragments; Jbuilder's cached hashes are mutated by Jbuilder.
- Not kept: one transaction for a post (FTS insert and unread update inside it): no change, again.
- Left on the table: the room composer (~16% of a room page; per-room output plus a per-form token),
  the involvement bell's dialog (~7%; depends on the user agent's platform), the push job's N+1
  (subscription users and unread counts, in the Resque workers that share the 4 CPUs), a boosts query
  for a message that was just created.

## Tools (~/Projects/campfire-perf/tools, synced to /opt/campfire-perf/tools)

- profile.sh IMAGE ROUTE [SECS] [CONC]: rbspy (blocking mode) per Ruby process; PUMA=1 runs the image under Puma.
- stacks.py, children.py: self/inclusive time and per-frame breakdowns from collapsed stacks.
- pagediff.sh A B: byte diff of 27 pages twice, static files and a post between two images.
- ab.sh A B [REPS] [ROUTES]: alternating quick A/B on c=16.
- build-opt.sh, build-commit.sh, sync-opt.sh.

## Final (bench/run-hetzner, SUITES=http, 3 reps alternating, 0 errors) — results/hetzner/rails-opt-final

| c=16 req/s | room | messages | sidebar | search | post |
|---|---|---|---|---|---|
| DHH (README) | 241 | 413 | 552 | 435 | 273 |
| falcon-fixes | 352 | 580 | 625 | 551 | 241 |
| rails-opt | 458 | 699 | 750 | 677 | 263 |
| change | +30% | +21% | +20% | +23% | +9% |

bench/run-hetzner exits 1 only because bench/report crashes on non-reference app sets (IndexError); the JSONs are complete.

## Pass 2 (Oct 6): the Rust port's documented divergences allowed

New bar (coordinator, from JP): match the reference except where once-campfire-rust's README "Known
differences" documents a divergence. Parity: tools/pagediff.sh against the stock image with only the CSRF
elements removed from both sides (csrf meta tags, authenticity_token fields) and the file_uploader.js
digest masked (its override is part of that divergence); ids and times that differ between runs stay
masked. Second pass of the diff now requests gzip. tools/headers.sh compares response headers on the
bench routes; tools/checkmode.sh runs CAMPFIRE_CHECK_CACHES=1 (every kept-page hit re-renders and
logs differences) across reads and posts from all 4 processes.

| Commit | Change | room | messages | sidebar | search | post | Parity |
|---|---|---|---|---|---|---|---|
| e70715f | Sec-Fetch-Site instead of CSRF tokens (header-only forgery protection; file_uploader.js override) | 447 → 508 | 706 → 820 | 736 → 736 | 667 → 727 | 260 → 268 | same but CSRF elements; cross-site, foreign/null Origin, HTTPS without header: 422 |
| 7b53b22 | Rewindable request bodies under Falcon (bot API raw body; 422 → 201, a falcon-fixes bug) | 493 → 507 | – | – | – | 277 → 267 (noise) | bot posts as stock |
| 36235a4 | Preload Link header resent with the kept asset tags (fixes 49b11e2, which dropped it) | not measured | | | | | headers as stock |
| d61f218 | Keep each page's gzip by body digest; Rack::ETag back | 494 → 531 | 824 → 991 | 715 → 764 | 721 → 745 | 268 → 263 | headers as stock (+304s) |
| 7b4b92e | ReadCache: query results kept until PRAGMA data_version / own writes | 519 → 555 | 986 → 1086 | 768 → 891 | 740 → 843 | 263 → 259 | same |
| 1e2ac5b | KeptResponses; finished sidebar by generation + request inputs | 564 → 563 | 1082 → 1091 | 885 → 2890 | 840 → 839 | 257 → 256 | same; check mode clean |
| 886e2cf | Finished room, messages, search pages | 543 → 2452 | 1085 → 2481 | 2846 → 3039 | 835 → 2959 | 255 → 262 | same; check mode clean |
| afa98e6 | Cookies only on change (session_token on sign-in/hourly refresh, last_room on change, session cookie on data change) | 2472 → 2886 | 2542 → 3040 | 3029 → 3713 | 2955 → 3607 | 263 → 268 | same; cookie flows checked |
| abe0675 | Push job: users preloaded, one badge count per user, no mentions query without mentions | – | – | – | – | 271 → 274 | same notifications (recorded through the pool) |
| – | In-process jobs (Rails AsyncAdapter threads, then a Falcon-fiber adapter, patches/in-process-jobs.diff + fiber_job_adapter.rb) | ~0 | ~0 | ~0 | ~0 | 270 → 228 (−16%) | not kept |
| – | Per-process fiber-aware writer lock (one SQLite busy-poller per process) | – | – | – | – | 221 → 225 (with in-process jobs) | not kept |

Why in-process jobs lose here: CPU per post is the same (~13-14 ms, slightly less in-process), but with
Resque the container uses 3.7 of 4 cores during the post load and in-process only ~3.0. Each Falcon process
is one thread, and SQLite's C calls (statement steps, WAL writes) block its reactor, so a web process can't
overlap its own job work with its writes; the two Resque processes used the CPU the web processes left idle.
6 web processes instead of 4 recover most of it (257 req/s), at more CPU per post.
| – | Avatar token signed once per process; no boosts query for a just-created message | – | – | – | – | 274 → 275 | not kept (no change) |

Per-request CPU after the pass (tools/cpuby.sh, ms of CPU per request by process, c=16): post: web 9.8,
Resque jobs 3.3, Thruster 0.3, Redis 0.3 (13.7 total; the container uses 3.7 of 4 cores). Room (kept page):
web 1.1, Thruster 0.2.

Divergences taken (all from once-campfire-rust's "Known differences"): CSRF by Sec-Fetch-Site; cookies only
on change; room/messages/search/sidebar ETags and kept responses (stock's Rack::ETag value for kept pages,
fresh_when's for messages). Not taken: in-process jobs (slower here, see above), permessage-deflate for
cable, the boot-time (room_id, created_at) index (the reference schema has it).

Code added in pass 2: app/controllers/concerns/same_origin_forgery_protection.rb,
app/controllers/concerns/kept_responses.rb, config/initializers/read_cache.rb,
lib/rails_ext/gzip_cache.rb, lib/rails_ext/changed_session_cookie_store.rb; small edits in
Authentication, TrackedRoomVisit, FormsHelper (token_tag), the four page actions, the push job.

Tools added: headers.sh (headers on the bench routes per image), checkmode.sh (CAMPFIRE_CHECK_CACHES=1
reads around posts from all processes), cpuload.sh / cpuby.sh (CPU use during a load), post_sql.rb
(statements in a post), push_check.rb (notifications a push queues), parity-railsopt.sh (Playwright
batches against campfire-railsopt-candidate, built from parity/docker/Dockerfile on the rails-opt image
with the reference's parity-base patch).
| b868f70 | Rack::Deflater back in config.ru (Thruster left images etc. uncompressed); GzipCache inside it | 2868 → 2842 | 3044 → 3023 | 3626 → 3629 | 3590 → 3538 | 270 → 261 | Playwright b1 network diffs fixed |

## Parity status after pass 2

- Server-HTML diff (tools/pagediff.sh) vs the stock image: identical on 58 responses (27 pages fetched
  twice, the second time gzipped and after a post; robots.txt, 404.html, 3 assets; the post's turbo
  stream), masking only the CSRF elements, the uploader's override digest, and per-run ids/times.
- Response headers on the bench routes: same as stock except the documented cookie divergence and 304s on
  revalidation (stock's bodies changed every request).
- Check mode (CAMPFIRE_CHECK_CACHES=1) over reads around posts from 4 processes: no kept-response mismatches.
- **Playwright harness, whole default-seed inventory (6 batches, round r3 on b868f70, ports 4311/4312,
  `parity/out/rails-opt-r3` on the box): 874 of 874 cells pass, 0 allowed, 0 fail, 0 error.**
  (Rage round 3: 863 pass, 1 allowed, 10 error.) Setup: candidate = parity/docker/Dockerfile on the
  rails-opt image plus the parity-base patch the reference image uses (tools/parity-base-railsopt);
  the box's once-campfire-rust copy got `crates/assets/overrides/models/file_uploader.js` so the
  harness masks that override's digest, as it does for the Rust port.
- Round r1 found the one real network difference: public responses (logo, SVG/PNG assets) lacked
  Content-Encoding because falcon-fixes had dropped Rack::Deflater; fixed in b868f70.

## Final after pass 2 (bench/run-hetzner, HTTP + cable, 3 runs rotating the app order, 0 errors)

`results/hetzner/rails-opt-pass2-final` (rails-opt image b868f70, Rage image of 12:59, falcon-fixes of Oct 5).
bench/run-hetzner exits 1 only because bench/report crashes without a reference app; the JSONs are complete.

| c=16 req/s (median of 3) | room | messages | sidebar | search | post | avatar | static css | /up |
|---|---|---|---|---|---|---|---|---|
| DHH (README, his machine) | 241 | 413 | 552 | 435 | 273 | | | |
| falcon-fixes | 343 | 572 | 613 | 546 | 240 | 62468 | 84041 | 4034 |
| rails-opt (pass 1 final) | 458 | 699 | 750 | 677 | 263 | | | |
| **rails-opt (pass 2)** | **2887** | **2932** | **3709** | **3631** | **268** | 61044 | 85672 | 6019 |
| Rage | 18495 | 25409 | 35865 | 28516 | 1842 | 178393 | 209402 | 107165 |

c=64: rails-opt 2950 / 3132 / 3847 / 3805 / 268. c=1: rails-opt 1174 / 1187 / 1449 / 1443 / 139.

Cable (median per-client delivery p50, delivered msgs/s under load; 90/90 messages delivered everywhere):
falcon-fixes 13.9 ms / 90 at 100 clients, 38.2 ms / 13 at 1000; rails-opt 14.0 ms / 83, 40.1 ms / 12 (no cable
work in this pass); Rage 2.4 ms / 1124, 4.8 ms / 194.

## Final parity (Oct 7, image from b868f70)

Image `campfire-reference:rails-opt` f76aaed2a853 / candidate 018c98db66af. Tracked files match b868f70
(sha256 per path); only Docker-ignored files (test/, .github/, README etc.) are absent, and the candidate's
config/resque-pool.yml is the harness's one-worker patch, the same one the reference parity image gets.
Default seed: round r3 on this image (874/874), not rerun. Results: `results/hetzner/final-20261007-parity/`.

| Seed | Cells | Pass | Fail | Error | Allowed |
|---|---|---|---|---|---|
| default (r3) | 874 | 874 | 0 | 0 | 0 |
| crowd | 25 | 25 | 0 | 0 | 0 |
| custom_styles | 33 | 33 | 0 | 0 | 0 |
| first_run | 16 | 16 | 0 | 0 | 0 |
| restricted | 8 | 8 | 0 | 0 | 0 |

## Pass 3 (Oct 7): only caching the Rust or Elixir ports do, and the audit's fixes

Rule: keep a cache only when the Rust port (basecamp/once-campfire-rust) or the Elixir port
(basecamp/once-campfire-elixir PR #5) does the same, checked in their source.

| Commit | Change | Precedent |
|---|---|---|
| 5694cce | Room and search pages render on every request (no kept response). SearchesController is back to the stock code. | Rust renders every request (crates/views/src/recorded.rs); Elixir assembles room/search from cached parts (room_page.ex, searches.ex) |
| 025b8be | Messages page kept by the ETag fresh_when computes per request, not until any write | Elixir keeps the messages page per ETag (messages.ex) |
| 115de7b | Sidebar still kept until the database changes; comment cites Elixir | Elixir keeps the sidebar's HTML until its tables change (sidebar.ex) |

Still in place, each with precedent: the per-process fragment cache (Rust and Elixir cache message
fragments), the data_version read cache (Elixir's DB.cached, invalidated by table generations), and
gzip kept by body digest (Rust's deflater reuse, Elixir's http_compression.ex).

Audit fixes (notes/audit.md, R4-R6 and C7/C9):

| Commit | Fix | Checked on the box (stock / before / after) |
|---|---|---|
| 5694cce | POST /searches runs the search before recording it (R4) | `q=OR`: 500 not saved / 302 saved / 500 not saved |
| 1e00c72 | Sign-out writes the rotated `_campfire_session` (R5) | cookie written: yes / no / yes |
| e8ab8ce | Active Storage controllers check Sec-Fetch-Site, as Rust's direct uploads do (R6) | direct upload: 200 / 422 / 200; cross-site: 422 |
| f6e0000 | busy_timeout on the data_version connection (C9) | – |
| 544b4bb | GzipCache keyed by SHA-256, not MD5 (C7) | – |

Image campfire-reference:rails-opt-fix1 from 544b4bb, labelled
org.opencontainers.image.revision=544b4bbdfb1d1d9fa6c93880cc160df4f7151529.

A/B, rails-opt (b868f70) vs rails-opt-fix1 (544b4bb), c=16, 4 alternating reps, fresh seed each
(tools/ab.sh), median [range]:

| Route | b868f70 | 544b4bb | Change |
|---|---|---|---|
| room | 2944 [2872-3037] | 523 [514-534] | −82% |
| messages | 3112 [3051-3206] | 2017 [1986-2058] | −35% |
| sidebar | 3727 [3685-3858] | 3615 [3574-3636] | −3% |
| search | 3697 [3629-3779] | 859 [845-861] | −77% |
| post | 267 [260-270] | 270 [265-272] | +1% |

Room and search fall back to about where they were before whole-page keeping (543 and 835 in pass 2).
The messages page keeps most of its gain, because the ETag is computed from the page's records on
each request and an unchanged page is served from the per-ETag copy. An Elixir-style memo of the room
shell (composer, nav, notification dialog) wasn't added.

Parity on 544b4bb:
- Server-HTML diff against stock (tools/pagediff.sh, CSRF elements masked): identical on all 58 responses.
- Playwright, full default-seed inventory (parity/out/rails-opt-fix1b): 874 of 874 cells pass, 0 fail,
  0 error, 0 allowed.
- A first run (rails-opt-fix1) errored on cable readiness. That was a harness mistake: the candidate
  image was built from parity/docker/candidate (the Rust one) instead of parity/docker/Dockerfile,
  so it lacked parity_action_cable.rb and the one-worker resque-pool.yml. The rebuilt candidate
  passed everything.
