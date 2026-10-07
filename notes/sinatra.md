# Campfire on Sinatra + Falcon

`~/Projects/campfire-perf/apps/sinatra` (own git repo, local commits only). Image `campfire-sinatra:app`
on the Hetzner box, built from `apps/sinatra/Dockerfile` (reuses the reference image's digested assets).
`bench/run-hetzner` maps the app name `sinatra` to it (one marked HETZNER CHANGE line).

## Design

- Sinatra (modular) on Falcon, forked, one process per CPU (`WEB_CONCURRENCY`, 4 in the bench).
- sqlite3 gem directly: per process one reader and one writer connection, prepared statements cached,
  WAL + synchronous=NORMAL. Writes take a fiber-aware lock and BEGIN IMMEDIATE.
- Erubi templates ported from the reference ERB, compiled into methods at boot. Message fragments cached
  per process by (message id, updated_at, host), like Rails' fragment cache.
- Rich text: the reference's own pipeline (content filters, Action Text attachment rendering and
  sanitizer, rails_autolink) on the same gems (nokogiri, rails-html-sanitizer, loofah) and the allow
  lists the Rails app ends up with at runtime.
- Rails-compatible crypto (`lib/campfire/rails_compat.rb`): signed and encrypted cookies, signed ids,
  Turbo stream names, Active Storage signed ids, variation keys and disk keys, signed GlobalIDs. Checked
  against values the reference produced.
- Action Cable protocol over async-websocket; cross-process fan-out through Redis pub/sub (Redis runs in
  the container, like the reference's). Channels: Turbo::StreamsChannel, RoomMessagesChannel, Presence,
  TypingNotifications, UnreadRooms, ReadRooms, Heartbeat.
- Jobs (push, webhooks, banned content removal) run in-process on a small thread pool.
- YJIT on (`RUBY_YJIT_ENABLE=1` in the image); each Falcon worker logs "YJIT enabled" at boot.
- Falcon hosted by `falcon.rb` (forked, one process per CPU, no ContentEncoding middleware); the Rack
  stack in config.ru: DateHeader (Thruster's Date), SSL (assume_ssl/force_ssl unless DISABLE_SSL),
  ResponseCache (Thruster's public-response cache), Compression (Thruster's gzip, with gzip kept by
  body digest; bodies over 1 MB stream), ETag, then /assets/ by prefix, else RequestId/Runtime and
  the app or /cable.
- Read cache per process (`DB::ReadCache`): rows and the records built from them, cleared when
  `PRAGMA data_version` changes (checked per request, cable command and job) or after own commits.
- Page caching matched to the Elixir port (lib/campfire/{room_page,searches,messages,sidebar}.ex), and
  nothing beyond it (since bbddf04): room and search pages are assembled on every request from a kept
  shell (keyed by everything its templates read except the messages) plus each message's cached
  fragment and compressed block; the messages page keeps its parts and gzip by its ETag; the sidebar
  keeps its finished HTML until the database changes. `CAMPFIRE_CHECK_CACHES=1` renders every hit in
  full as well and compares.
- WAL checkpoints in `bin/checkpoint` (its own process, restarted if it exits), app connections
  `wal_autocheckpoint=0`.
- gzip in-process at zlib's default level; Rack::ETag behavior (MD5 of body, or of the inputs for the
  big message pages).

## Divergences (all taken from the Rust port's choices)

- CSRF: `Sec-Fetch-Site`/`Origin` checks replace tokens, exactly as the Rust port specifies them
  (null or foreign Origin fails; same-origin/same-site pass; a missing header passes only without
  SSL; anything else fails; failures answer the public 422 page). Pages carry no CSRF meta tags or
  token fields; `overrides/models/file_uploader.js` (identical to the Rust port's override) sends no
  token, installed over the reference's assets at build time (since 31f73ed).
- Cookies: `session_token` is written on sign-in and on the hourly activity refresh, not every request;
  `last_room` only when it changes; `_campfire_session` only for flash and the post-login redirect.
- Jobs are in-process (no Resque); queued pushes/webhooks are lost on a crash.
- ETags on room, messages and search pages hash their inputs (user, host, user agent, the page's
  records and message versions) rather than the body. The Rust port hashes the cached page parts;
  both change exactly when the page does.
- WAL checkpoints run in their own process instead of inside a commit (not visible in responses).
- Public responses are cached per process (Thruster's cache is one per container), so a second
  request that reaches another worker says `X-Cache: miss` where the reference says `hit`.

## Whole-page keeping removed (Oct 7)

Room, search and messages pages are no longer kept whole until the database changes. Neither the
Rust nor the Elixir port does that. They're now assembled on every request the way Elixir does it
(bbddf04): a kept shell plus each message's cached fragment and compressed block for room and search,
and parts + gzip by ETag for the messages page. The sidebar keeps its finished HTML, as Elixir's
sidebar.ex does.

What whole-page keeping was worth (`.work-sinatra/ab.sh`, c=16, 8 s, a fresh seed and probe per
measurement, 4 alternating reps, 0 errors; image m75f85be = 75f85be, s1 = bbddf04):

| Route | Whole page kept (75f85be) | Assembled per request (bbddf04) | Change |
|---|---:|---:|---:|
| Room | 23,724 [23,687–23,899] | 13,634 [13,536–13,731] | −43% |
| Search | 23,566 [23,443–23,756] | 16,571 [16,538–16,836] | −30% |
| Messages | 25,902 [25,595–26,035] | 21,037 [20,964–21,103] | −19% |

Medians [min–max]. Raw: `.work-sinatra/ab-s1.txt` on the box.

## Audit fixes (Oct 7, notes/audit.md)

One commit each, on main after bbddf04:

| Finding | Fix | Commit |
|---|---|---|
| S1 stored XSS | Blobs served with Active Storage's content_type_for_serving / forced_disposition_for_serving (the Rust port's lists) | 94e7470 |
| S2 / D6 /cable any Origin | Same-origin-as-host check, 404 "Page not found" otherwise | 954b64f |
| S3 bot API CSRF, D2/D3/D4/D16 | Forgery check as the Rust port specifies it (null/foreign Origin, Sec-Fetch-Site values, no header only without SSL), public 422 page, authentication before the check, bot writes by cookie checked, return_to for every method | c229222 |
| S4 marker injection | Markers carry a boot-time secret | 3582df3 |
| first_run 500 | Logo path and logo check without an account; manifest small-logo URL | 3ef3adf, 418d230 |
| S7 / D9 email case | Stored as typed, as Rails and Rust do | 03e82d1 |
| S5 / D10 push on sign-out | push_subscription_endpoint removed on sign-out | f5cc252 |
| D7 private-IP bans | Ban#ip_address_is_public; RecordInvalid → 422, ban rolled back | 3cc5b1f, 09882fe |
| D8 boosts | Stored whole; boost create/destroy touches the room too | 48a8191 |
| S6 / D5 HTTPS | assume_ssl/force_ssl unless DISABLE_SSL: https scheme, HSTS, Secure cookies | 4ed2bb0 |
| D11 / D12 headers | X-Request-Id, X-Runtime, Date (real clock under FAKETIME) | 7705f46 |
| C1 StaticFiles | Kept under the canonical path only | a526053 |
| C2 public cache buffering | Bodies over 1 MB stream (no cache, gzip as sent); Vary index bounded | 80cd5a8 |
| D1 CSRF meta tag | Removed; overrides/models/file_uploader.js (Rust's) installed at build | 31f73ed |
| D4 browser check order | AllowBrowser runs last, after ban, auth and forgery | da802e8 |
| D14 / D15 | If-Modified-Since 304s for public/ files, HEAD 304s, Range → X-Cache bypass | bc1f181 |
| D24 checkpointer | Restarted if it exits | 1dd8a67 |

Left as is, and why:
- D13 per-worker public cache (`X-Cache: miss` where Thruster says `hit` for a request that lands on
  another worker): Thruster's cache is one per container; ours is one per Falcon process. Documented.
- D18 turbo-stream whitespace on message create: bodies are identical after the harness normalizes.
- C3 whole-page cache byte bounds: the whole-page caches are gone; the shell and messages-page caches
  are capped by entry count (512 each) like the fragment cache.
- C5-C8 nits.

## Final parity on the fixed code (Oct 7)

Image `campfire-sinatra:f1` 31ca2dbf96fc / candidate ad4d7d9ab801, built from the box tree whose 97
tracked code files match main (93d5f24; code unchanged since 418d230) by sha256. Default ports
4111/4112, `.work-sinatra/final-fix.sh`.

| Seed | Cells | Pass | Fail | Allowed | Error |
|---|---:|---:|---:|---:|---:|
| default (6 batches) | 874 | 874 | 0 | 0 | 0 |
| first_run | 16 | 16 | 0 | 0 | 0 |
| crowd | 25 | 25 | 0 | 0 | 0 |
| custom_styles | 33 | 33 | 0 | 0 | 0 |
| restricted | 8 | 8 | 0 | 0 | 0 |

Before that, on the s3 image: the server-HTML diff of every page in script/paths.txt was identical,
all 24 write flows matched, with `CAMPFIRE_CHECK_CACHES=1` logging no mismatches. On s1 (the
page-assembly change alone) the stale-read check read 136 pages after posts and a rename across 4
workers with none stale.

Security checks (`.work-sinatra/sec-check.sh f1`, results in `sec-f1.txt`):
- an HTML upload is served as application/octet-stream with an attachment disposition
- /cable from a foreign Origin gets 404 "Page not found"; from its own origin, 101
- a write with `Origin: null`, `Sec-Fetch-Site: none` or `cross-site` gets the public 422 page
- `GET /searches?q=%01999%02` gets 200
- X-Request-Id, X-Runtime and Date are on page responses
- HEAD with a matching If-None-Match gets 304
- a static file under `/assets//...` still serves

The one line marked FAIL there is the script's own count: the 422 page has "That didn't work" in
its title and heading, so the count is 2, not 1.

## Parity status (Playwright harness)

`parity/bin/candidate compare` on the box, reference vs `campfire-sinatra-candidate`, default seed,
the inventory in `parity/screens.yml`, in batches under the bench lock
(`/opt/campfire-perf/.work-sinatra/rebuild-and-batch.sh NAME GLOBS`; reports in
`once-campfire-rust/parity/out/sinatra/`). Every layer: pixels, server HTML, live DOM, aria, network
headers/bodies, cable.

Harness setup on the box: the parity reference image is built on a patched base image
(`.work-sinatra/parity-base/`: creates /rails/log, and turns off ActiveRecord's migration timestamp
validation, which fails under the frozen clock).

Inventory: 206 states; 184 use the default seed, 22 need other seeds (crowd 7, custom_styles 9,
first_run 4, restricted 2) and haven't been run (their seeds aren't built on the box).

**After the optimization pass (round r2, image b99c0c9, whole default-seed inventory in 6 batches,
`parity/out/sinatra/r2-*`): 874 cells, 873 pass, 1 allowed (pwa/manifest, the Rust port's
allowlist entry), 0 fail, 0 error.** pwa/manifest now matches Rails exactly (9825d44); pwa/**,
realtime/** and messages/** were run again on the final image 3591f56 (`r3-pwa-rt`): 280 of 280
cells pass, pwa/manifest included (no allowed cells).

Default seed, latest result per state (822 cells, batches b1–b9): all 184 states pass; one of
them (pwa/manifest) passes through the Rust port's allowlist entry. Each state's latest run is on
the image of its batch; there's been no single full rerun on the final image (8aac9d6). The last
fixes, each rerun on the image with it:
- interactions/edit_form: the edit page needed the full layout for frame requests.
- realtime/boost_removed: a 204 write gets Cache-Control no-cache and one Vary.
- realtime/removed_from_room: Rails closes a user's cable connections when they lose a membership
  (and on ban, deactivation, sign out); added, through the Redis channel to every process. Room
  updates also touch updated_at only when the name or type changes (the refresh's `since` comes
  from it).
- realtime/room_deleted_then_send: posting to a deleted room renders messages/room_not_found in
  the layout (the composer frame shakes); it was a turbo-stream.
- bot_api/messages/update: the bot update takes the raw body, like create.
- bot_api/boosts/create: the bot boosts endpoints were missing.

Fixed along the way (each from a harness diff):
- Banned IPs never matched: header strings arrive binary-encoded and sqlite3 binds them as BLOBs.
  Bound as UTF-8 text now (also the sessions' user agent and IP).
- `head` from a before-action is `text/html` whatever the Accept header (Rails sets formats after
  the callbacks); only heads inside actions use the request format.
- Sidebar direct rooms: Rails caches each in Redis by membership id + updated_at, and
  PresenceChannel marks rooms read with update_all, so a room read after its fragment was cached
  still shows unread in the next sidebar load. Reproduced with the same Redis cache (MGET per
  sidebar), so this is no longer a known gap.
- MessagesController's `layout false, only: :index` replaces turbo-rails' frame layout, so message
  show/edit render the full layout (and its Link header) for frame requests.
- Rack::ETag tags 200s of any method, not just GETs.
- Byte ranges on assets (206, uncompressed, Vary twice); the sound player asks for them.
- The autocomplete fragment ends with the template's extra newline.

Byte differences the harness doesn't compare: the message create turbo-stream's whitespace
differs from Rails' (POST bodies aren't compared and the live DOM is the same).

## Security fix found while widening parity

`MessageVerifier#verify` accepted any signature of the wrong length (a `rescue` modifier swallowed
the length error instead of rejecting). That would have let a forged transfer link sign in as any
user and any blob be downloaded. Fixed in commit "Reject signatures of the wrong length"; the
checkpoint image had it, but it only ever ran on loopback test instances.

Second security fix (75f85be, after the pass): sign-in for an email with no active user skipped
bcrypt (~10 ms against ~150-250 ms for a wrong password), revealing which addresses have accounts.
It now compares against a precomputed cost-12 digest, as Rails' authenticate_by and the Rust port
do; both cases now take 146-159 ms.

## Efficiency

- Message fragments are cached per process, as in Rails.
- gzip: each run of consecutive cached messages keeps its compressed block, so a page only
  compresses its own head and tail per request. The room page compresses to 21 KB (20.6 KB as one
  stream) and costs about 1.95 ms locally instead of 3.2 ms. Not in the checkpoint numbers below.

## Optimization pass (Oct 6), after notes/elixir-rust-optimizations.md, rage.md and rails-opt.md

Each change measured with `.work-sinatra/ab.sh A B ROUTES REPS` on the box: a fresh probe (fresh seed
copy, 4 workers on CPUs 4-7, loadgen on 0-3) per measurement, 3 s warm-up, 8 s at c=16, image order
alternating between reps, medians; each measurement under the bench lock. Kept only with the page
diff (`script/box-pair` + `script/compare` over `script/paths.txt`: 64 pages, as Rage's) and the 24
write flows (`script/flows`) unchanged against the reference (`.work-sinatra/parity-check.sh`), and
for the caches with `CAMPFIRE_CHECK_CACHES=1` (every kept-page hit re-rendered and compared, the
plain-text fast path run through the full pipeline too): no mismatches. `stale-check.sh` reads pages
on fresh connections across 4 workers after posts and a room rename: never stale. One commit each.

| # | Change | Commit | c=16 req/s, median | Source |
|---|---|---|---|---|
| 0 | Room ids from any path segment (`/rooms/abc` redirects home, as Rails casts the id); box-pair, paths.txt | b6ad418 | parity | Rage b97ed3d |
| 1 | Split pages on fragment markers by byte offset | e3f5ecc | room 2595 → 3065, search 4053 → 4350 | Rage 7734116 |
| 2 | Keep each page segment's deflate block; one CSRF meta token per process | 32039ac | room 3049 → 4164, search 4319 → 5771 | Rage c83ab7b |
| 3 | Keep a body's gzip under the ETag middleware's MD5 | 98021cd | sidebar +1.4% (but see 7) | Rage a98f212 |
| 4 | Post without reloading the new message (`Messages.post`, `create_with_details`, `after_create(created:)`, push job gets body/plain/creator) | 8f1a529 | post 1678 → 1842 | Rage 251d43f |
| 5 | Read cache cleared on `PRAGMA data_version` (checked per request, cable command and job: Falcon serves a keep-alive connection's requests on one fiber) and own commits | 2c86dd0 | messages 7038 → 8485, room 4154 → 4816, search 5793 → 7235, sidebar 4127 → 4778 | Rage 807a8e1 |
| 6 | Finished sidebar by generation + user + request inputs, check mode | b249617 | sidebar 4868 → 7818 | Rage 34bd5c8 |
| 7 | **Build the Rack stack once.** config.ru ran a `Rack::Builder` as the app, which rebuilds every middleware per request, so #3's kept gzip never survived | a0cf295 | sidebar 7782 → 16698, css 55.6k → 79.5k, /up 20.4k → 26.7k | Sinatra bug |
| 8 | Finished room, messages, search pages (`kept_response`: generation + page ETag + frame + Accept + encoding), check mode | 5824aa5 | room 4988 → 12236, messages 8941 → 13983, search 7429 → 13410 | Rage 39dbd64, d4a8b90 |
| 9 | **Run in production; accept any Host.** The image ran Sinatra in development: host authorization answered 403 to any non-localhost Host and built a debug string of its allow list per request | ec1ccab | room 12278 → 14457, sidebar 16693 → 20814, /up 26.8k → 38.9k | Sinatra bug |
| 10 | Host Falcon without its ContentEncoding middleware (`falcon.rb`; it re-indexed every response's headers) | e74054a | room 14528 → 16490, sidebar 20953 → 22638, /up 39.0k → 44.3k, css 77.8k → 88.7k | profile |
| 11 | Keep the records built from cached reads (repo lookups memoized, frozen) | 345b5f1 | room 16675 → 18947, messages 17975 → 20667, search +6% | profile |
| 12 | Remember signatures already verified (session cookie HMAC; expiry and purpose still checked) | 69a39e0 | room 19011 → 21244, sidebar 23070 → 26719 | Elixir/Rust |
| 13 | Thruster's response cache for public responses | 07a07a3 | avatar 16.4k → 82.6k, css +8.8% | Rage 3ce184c |
| 14 | Header fixes from a header comparison outside the harness: kept sidebar resends its Link header; send_file responses don't vary on Accept, /up does; avatar sign-in redirect without security headers | 36ec177 | parity | – |
| 15 | WAL checkpoints in their own process (`bin/checkpoint`; app connections `wal_autocheckpoint=0`, Rails' journal_size_limit and cache_size) | 82050e6 | post 1915 → 2100 | Rust |
| 16 | Plain-text bodies skip the rich text pipeline (same output, checked) | ecf1b4d | post 2084 → 2870 | profile |
| 17 | A post's broadcasts in one PUBLISH | 410a6d5 | post 2872 → 2992 | Rust/Elixir |
| 18 | Retry a busy write lock every 100 µs instead of 1 ms | 6da8ca4 | post 2956 → 3536, cores 2.6 → 3.2 | profile |
| 19 | Route /assets/ and /cable by prefix (no Rack::URLMap); one before filter | 2d97a37 | messages +5.4%, sidebar +4.8%, /up +8.4% | profile |
| 20 | Keep the message-versions part of page ETags | b99c0c9 | messages 24633 → 26692, room 22079 → 23597, search +2.5% | profile |
| 21 | Web app manifest's small logo URL HTML-escaped as Rails' ERB writes it (the Rust port's one allowlisted difference, now matched) | 9825d44 | parity | – |
| 22 | Checkpoint once 1,000 WAL frames wait (read from the -shm header), not every 50 ms: #15's timer fsynced the WAL up to 20×/s and paced posts stalled (cable suite post p50 4 → 18 ms; found in the final bench) | 3591f56 | cable post p50 17.0 → 2.7 ms, delivery p50 17.9 → 3.7 ms; c=16 post within the spread | – |

Not kept: nothing measured worse; JOB_CONCURRENCY 1/2/4 makes no difference to posting.

### Posting

Profiled with rbspy (`profile.sh`) and timed per transaction (a temporary build). At the start of
the pass a post cost 1.5 ms of CPU and the container used 2.9 of 4 cores. Where it went:
- **COMMIT included the WAL auto-checkpoint**: every ~64 posts one commit copied the WAL into the
  database and fsynced, while holding the write lock; the other three workers' posts waited (#15).
- **Rich text**: four Nokogiri parses and three sanitizer passes for a body that is plain text
  (12% of a post); now a checked fast path (#16).
- **Lock handoff**: the four workers queue for SQLite's write lock, and a worker that found it taken
  slept a full millisecond before retrying, while a write holds it for a few hundred microseconds
  (#18). Rust has one process and a writer thread fed by a queue, so it has no handoff gaps.
- **In-process jobs** are threads here (2 per worker), not fibers, so they don't serialize with the
  reactor the way rails-opt's fiber jobs did; they're ~3% of a post's samples and JOB_CONCURRENCY
  1, 2 and 4 measure the same. The idle cores came from the two lock waits above.
Now: 0.9 ms of CPU per post, 3.2 cores busy, 3536 req/s (from 1678 at the start of the pass).
What's left is the write itself (the FTS insert and the memberships update are in the same
transaction as in Rails) and the serialization across processes.

### Final run after the pass

`bench/run-hetzner`, HTTP + cable, 3 single-rep runs rotating the order (sinatra,rage,rails-opt /
rage,rails-opt,sinatra / rails-opt,sinatra,rage), 0 errors: `results/hetzner/sinatra-pass2-final`
(images: Sinatra 9825d44, Rage 3ce184c, rails-opt b868f70). That run showed Sinatra's cable post
latency up from ~4 to ~14 ms (#22), so Sinatra was run again alone, 3 reps, on the fixed image
3591f56: `results/hetzner/sinatra-pass2-final-sinatra`. Sinatra rows below are from that rerun;
its HTTP numbers match the first run within 1-3%. bench/report crashes without a reference app;
the JSONs were read directly.

c=16 req/s, median of 3 (ranges in the result dirs):

| | room | messages | sidebar | search | post | avatar | static css | /up |
|---|---|---|---|---|---|---|---|---|
| **Sinatra (after the pass)** | **23608** | **26042** | **25245** | **23867** | **3398** | 82425 | 100501 | 44937 |
| Rage | 18590 | 24788 | 33067 | 28688 | 1784 | 181609 | 205809 | 99543 |
| rails-opt | 2857 | 2958 | 3621 | 3508 | 256 | 61298 | 85173 | 5952 |
| Sinatra before the pass (YJIT run) | 2572 | 6837 | 4153 | 4139 | 1694 | 10689 | 58726 | 23347 |

c=64: Sinatra 22908 / 25298 / 24558 / 23117 / 3402; Rage 18466 / 25195 / 35790 / 28368 / 1968.
c=1: Sinatra 6246 / 6868 / 6572 / 6303 / 1405; Rage 4948 / 6591 / 8669 / 7234 / 723.

Cable fan-out, every client got every message in every run (30/30, 0 failed):

| clients | delivery p50 Sinatra | Rage | rails-opt | delivered msgs/s Sinatra | Rage | rails-opt |
|---|---|---|---|---|---|---|
| 100 | 2.7 ms | 2.6 ms | 13.5 ms | 845 | 1117 | 83 |
| 500 | 5.3 ms | 3.7 ms | 24.9 ms | 207 | 308 | 24 |
| 1000 | 9.1 ms | 4.9 ms | 39.1 ms | 113 | 192 | 12 |

Memory: Sinatra idle anon 199 MB, peak anon 1.0-1.06 GB (peak cgroup 1.1-1.2 GB; was 1.8-1.9 GB
anon before the pass: the kept pages replace most per-request garbage); Rage 165-170 / 635-645 MB;
rails-opt 614-623 / 1.74-1.86 GB.

Reading: Sinatra is ahead of Rage on room (+27%), messages (+5%) and posting (1.9x) and behind on
sidebar (-24%), search (-17%) and the small responses (/up, assets, avatars: Iodine's C HTTP layer
is 2-2.2x Falcon's). Per request a kept page costs ~0.16 ms of CPU here, most of it Falcon's
HTTP/1 parsing and header handling, Sinatra's routing and Rack::Response, which Rage doesn't pay.

## Bench with YJIT (HTTP suite, 3 reps)

`bench/run-hetzner`, SUITES=http, three single-rep runs alternating app order, each under the bench
lock; same box and CPUs as the checkpoint. Sinatra image from commit 41e2238 (YJIT on, verified in
the four Falcon workers; includes the gzip-run cache, in-memory static files and the Redis sidebar
cache). falcon-fixes is the same image as at the checkpoint. Results:
`results/sinatra-yjit-vs-falcon-20261006-0335/` on the box. No errors.

At 16 clients (median of 3):

| app | room | messages | sidebar | search | post | avatar | static css | up |
|---|---|---|---|---|---|---|---|---|
| falcon-fixes | 346 | 579 | 622 | 551 | 244 | 61733 | 83695 | 4140 |
| sinatra + YJIT | 2572 | 6837 | 4153 | 4139 | 1694 | 10689 | 58726 | 23347 |
| sinatra / falcon-fixes | 7.4× | 11.8× | 6.7× | 7.5× | 6.9× | 0.17× | 0.70× | 5.6× |
| sinatra at checkpoint (no YJIT, older code) | 1316 | 2108 | 4003 | 2821 | 1529 | 10612 | 21318 | 18614 |

At 1 client: room 725, messages 2010, sidebar 1189, search 1127, post 572 (falcon-fixes 110, 189,
216, 186, 119). At 64 clients: room 2537, messages 6871, sidebar 4260, search 4096, post 1701
(falcon-fixes 339, 585, 620, 536, 245). The gains over the checkpoint mix YJIT with the later
code changes (gzip blocks cached per run of messages, static files from memory); the sidebar now
also makes one Redis MGET per request for its direct rooms.

## Bench checkpoint (priority 1)

`bench/run-hetzner` on the Hetzner box (Ryzen 7 PRO 8700GE), app on CPUs 4-7, loadgen on 0-3, all
three suites (http, cable, upload), three single-rep runs with the app order alternating
(falcon-fixes,sinatra / sinatra,falcon-fixes / falcon-fixes,sinatra), each run holding the bench lock.
Both apps run 4 processes. Image: apps/sinatra commit 05ca71a (before the gzip-run cache and the
in-memory static files). Results: `results/hetzner/sinatra-vs-falcon-20261006-0015/`. No errors in any run.

At 16 clients, against DHH's published Rails numbers (room 241, messages 413, sidebar 552,
search 435, post 273):

| app | room | messages | sidebar | search | post |
|---|---|---|---|---|---|
| DHH's Rails (his machine) | 241 | 413 | 552 | 435 | 273 |
| falcon-fixes (Rails + 3 config fixes, Falcon) | 338 | 567 | 615 | 548 | 242 |
| sinatra | 1316 | 2108 | 4003 | 2821 | 1529 |
| sinatra / falcon-fixes | 3.9× | 3.7× | 6.5× | 5.1× | 6.3× |

Thruster caches public responses, so falcon-fixes serves avatars and static CSS from Go's cache;
the Sinatra app serves them from Ruby (in-memory static files came after this checkpoint).
Peak memory, from the harness's samples of memory.stat (anon) next to memory.current: sinatra's anon
peak is 1.84–1.95 GB against falcon-fixes' 1.75–1.80 GB (+5–8%). The rest of sinatra's 2.8–3.4 GB
cgroup peak is file pages: the database's page cache after ~12k posts per run. Idle anon is 149 MB vs
611 MB. The anon growth under load is mostly the per-process fragment cache (up to 20,000 rendered
messages per process at the time); it's now capped at 5,000.

After the checkpoint (commit after 05ca71a: gzip blocks cached per run of messages, static files from
memory, Redis listener fix), one 8-second probe per route at 16 clients, same box and CPUs (not the
three-run harness): room 2414, messages 6399, sidebar 3778, search 3552, post 1435, static CSS 41641.

Full checkpoint tables:

## HTTP req/s at 1 clients (median [min-max] of 3 runs)

| app | room_show | messages_page | sidebar | search | post_message | avatar | static_css | up |
|---|---|---|---|---|---|---|---|---|
| falcon-fixes | 110 [109-110] | 187 [184-190] | 216 [216-217] | 186 [180-186] | 123 [122-124] | 19230 [19176-19241] | 23055 [22998-23708] | 1597 [1583-1621] |
| sinatra | 385 [384-386] | 598 [587-601] | 1104 [1095-1107] | 766 [761-776] | 516 [513-518] | 3004 [2992-3023] | 5697 [5683-5749] | 5038 [4997-5047] |

## HTTP req/s at 16 clients (median [min-max] of 3 runs)

| app | room_show | messages_page | sidebar | search | post_message | avatar | static_css | up |
|---|---|---|---|---|---|---|---|---|
| falcon-fixes | 338 [334-354] | 567 [566-580] | 615 [610-615] | 548 [539-557] | 242 [242-247] | 62625 [62557-63697] | 84370 [83565-85555] | 4110 [4070-4146] |
| sinatra | 1316 [1315-1322] | 2108 [2100-2113] | 4003 [3989-4004] | 2821 [2817-2844] | 1529 [1506-1533] | 10612 [10518-10686] | 21318 [21170-21435] | 18614 [18568-18626] |

## HTTP req/s at 64 clients (median [min-max] of 3 runs)

| app | room_show | messages_page | sidebar | search | post_message | avatar | static_css | up |
|---|---|---|---|---|---|---|---|---|
| falcon-fixes | 333 [333-345] | 578 [564-579] | 614 [595-615] | 548 [532-552] | 247 [242-250] | 51749 [51459-51780] | 73060 [71949-73492] | 4181 [4128-4302] |
| sinatra | 1312 [1307-1316] | 2096 [2088-2096] | 3972 [3961-3979] | 2811 [2792-2829] | 1488 [1453-1495] | 10566 [10554-10600] | 21246 [21180-21328] | 18608 [18436-18691] |

## Cable fan-out (median of runs)

| app | clients | ready | delivery p50 ms | p99 ms | delivered msg/s | complete |
|---|---|---|---|---|---|---|
| falcon-fixes | 100 | 100 | 19.6 | 54.0 | 89.4 | 4023/4023 |
| falcon-fixes | 500 | 500 | 46.2 | 101.1 | 25.7 | 1194/1194 |
| falcon-fixes | 1000 | 1000 | 81.8 | 180.0 | 12.8 | 649/649 |
| sinatra | 100 | 100 | 5.0 | 8.2 | 461.5 | 20790/20790 |
| sinatra | 500 | 500 | 10.9 | 31.6 | 162.9 | 7123/7123 |
| sinatra | 1000 | 1000 | 19.5 | 36.7 | 88.9 | 4080/4080 |

## Upload, memory, cold start (median)

| app | upload ms | idle MB | peak MB | cold start ms |
|---|---|---|---|---|
| falcon-fixes | 67.4 | 630 | 1863 | 5849 |
| sinatra | 42.5 | 154 | 2805 | 1138 |


## Final parity (Oct 7, image from 75f85be)

Image `campfire-sinatra:app` 46ecf4801036 / candidate 95df7ffe71eb. Every tracked file in the image matches
75f85be (checked by sha256 per path). Results: `results/hetzner/final-20261007-parity/sinatra-final*`.

| Seed | Cells | Pass | Fail | Error | Allowed |
|---|---|---|---|---|---|
| default | 874 | 874 | 0 | 0 | 0 |
| crowd | 25 | 25 | 0 | 0 | 0 |
| custom_styles | 33 | 33 | 0 | 0 | 0 |
| first_run | 16 | 0 | 0 | 16 | 0 |
| restricted | 8 | 8 | 0 | 0 | 0 |

- first_run: all four states (auth/first_run, /from_sign_in, /filled, /completed) get a 500 from
  `/first_run`. On a fresh install there is no account row, and `View#account_logo_path`
  (lib/campfire/view.rb:72, called from the layout) calls `account.updated_at` on nil. A new install
  can't be set up. Not fixed (held for JP, with the audit's findings).
- pwa/manifest now passes on the default seed (9825d44 matches Rails' escaping), so no allowlist entry is used.
