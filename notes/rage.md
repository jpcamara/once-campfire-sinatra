# Campfire on Rage + Sequel

`~/Projects/campfire-perf/apps/rage` (own git repo, local commits only). Image `campfire-rage:app` on the
Hetzner box, built from `apps/rage/Dockerfile` (reuses the reference image's digested assets).
`bench/run-hetzner` maps the app name `rage` to it (one marked HETZNER CHANGE line, next to `sinatra`).

Started from a snapshot of the Sinatra app at **69b4e3a**: templates, views, rich text, attachments,
storage, uploads, Rails-compatible signing (`rails_compat.rb`), time formats, translations and the domain
modules are that code, unchanged except where noted below. The HTTP layer, the data layer, the cable
server and the jobs are new.

## What TechEmpower's rage-sequel does, and what this app takes from it

Source: `FrameworkBenchmarks/frameworks/Ruby/rage-sequel` (rage-rb ~> 1.19, sequel + sequel_pg, Postgres).

| TechEmpower choice | Here | Why |
|---|---|---|
| `rage s -e production`, Rage's own server (rage-iodine) | Taken | The point of the comparison. |
| Workers: Rage's default (one per CPU) | Taken: `WEB_CONCURRENCY` (4 in the bench, the 4 app CPUs), 1 thread each | Same process count as the Sinatra and Falcon runs. |
| `config.logger = nil` in production | Taken (`RAGE_LOG=1` turns it back on) | Sinatra and Falcon don't log requests either. |
| `RUBY_YJIT_ENABLE=1` | Taken | JP: YJIT on for every app. The Sinatra image now sets it too (rebuilt 03:33). The Rails images enable it through `config.yjit` (Rails 8 default); checked inside running workers: 4 of 4 workers report `RubyVM::YJIT.enabled? == true` in falcon-fixes, rails-opt and the stock reference (a mounted initializer recorded it per serving process). |
| `Sequel.extension :fiber_concurrency`, `max_connections: 512` | Not taken | That's for Postgres, where queries yield to the fiber scheduler. SQLite calls never yield, so one connection per shard per process is enough, and each extra connection is another page cache. |
| `SEQUEL_NO_ASSOCIATIONS`, `Sequel::Model` with `with_pk`, `DB.freeze` | Not taken | No models: every query is a Sequel prepared statement returning rows that become `Data` objects (the Sinatra app's models). `DB.freeze` would stop prepared statements from being registered after boot. |
| `DB.synchronize` around a batch of queries | Not yet | Candidate tuning step: hold the reader connection for a whole request instead of per query. |
| ERB compiled once (`ERB.new(...)` at load), `render plain:` | Same idea, Erubi | Templates compile into methods at boot (the Sinatra app's View). |
| `BUNDLE_FORCE_RUBY_PLATFORM` | Not taken | Precompiled Linux gems are fine here. |

## Design

- **Rage**: router (`config/routes.rb`, the reference's routes), `RageController::API` controllers, one
  per resource. `Campfire::Web` gives every controller the response helpers the actions use (`halt`,
  `redirect`, `headers`, the Rails default headers, authentication, session and flash), so an action
  reads like the Sinatra route it came from: `action :show do ... end` returns the body.
- Middleware (Rage's `config.middleware`, inside its request fiber): `RequestMethod` (form `_method`
  override and HEAD, which Rage doesn't do), `Compression` (Thruster's gzip), `ETag` (Rack::ETag),
  `AssetFiles` (digested assets from memory).
- **Sequel** over SQLite (`lib/campfire/db.rb`): one database per process with two shards, `:read_only`
  for reads and `:default` for transactions. Every query is a Sequel prepared statement cached by its SQL.
  Sequel's type conversion is off (text timestamps stay text, as the app expects). WAL,
  `synchronous=NORMAL`. Writes take a fiber-aware lock, because Sequel tracks transactions per thread
  and every Rage request runs on one thread.
- **Rage::Cable** with `Campfire::CableProtocol`: Action Cable's v1 JSON protocol framed exactly as Rails
  frames it (raw identifier, Action Cable's encoding of the payload, `unsubscribe`, unknown actions
  ignored, pings with the time). Broadcasts go to every worker over Iodine's cluster pub/sub (no Redis)
  and reach the subscriptions each worker holds when they arrive, then go out through Iodine's
  per-subscription channels. Channels are Rage channels (`app/channels`).
- **Jobs** (push, bot webhooks, banned-content removal): `Rage::Deferred`, in memory, no retries.
- **Redis** only for the sign-in rate limit (shared counter across processes), as the reference does.

## Things Rage or Sequel needed help with

- Iodine hands params over as binary strings; SQLite binds those as blobs, so `email = ?` never matched.
  Params are forced to UTF-8.
- Sequel turns on `PRAGMA case_sensitive_like`; Rails doesn't, and mention autocomplete relies on it.
- Rage's router has no static suffix after a parameter (`:id.json`), so the bot API strips `.json`.
- Rage's scheduler hands file reads to Iodine, which waits for a readiness event between 64 KB chunks of
  a regular file. On an idle server that event only comes with the next request, so the first request
  for a larger asset (or a disk blob, or an upload) stalled. Local file IO runs in `Fiber.blocking`.
- Iodine's form parser rejects bodies Rack accepts (raw UTF-8 such as a bot's `curl -d '🎉'`, or no
  content type); those fall back to Rack's parser (`lib/campfire/form_params.rb`).
- Strings from Iodine (headers, the client's address) are binary-encoded and SQLite binds them as blobs:
  the banned-IP check never matched and sessions stored blobs. Binds are forced to UTF-8.
- Rage::Cable 1.28's built-in Action Cable protocol re-serializes the identifier, answers unknown actions
  with a disconnect, has no `unsubscribe`, and drops a broadcast for a subscription made a moment later
  in the same worker (it resolves subscribers when publishing). The custom protocol fixes all four.
- No HEAD routing and no method override in Rage; `RequestMethod` does both.
- Rage's router has no `(.:format)`. Rails routes `/account.<id>` (what `form_with model: Current.account`
  posts to) to accounts#update; `RequestMethod` maps it to `/account`. Other format-suffixed paths still
  404 here where Rails would serve them (`GET /account/edit.html`); the app's own pages don't link any.
- Iodine's `rack.input#read(length, buffer)` leaves the buffer's cached coderange stale, so Rack's
  multipart parser takes binary parts for ASCII and raises. `RequestMethod` parses `_method` from the bytes
  it already read (a StringIO). Upstream issue draft: `notes/iodine-rack-input-coderange-issue.md`.
- Under the parity harness's libfaketime clock, Iodine stamps the frozen time as `Date`, which makes cached
  assets stale on arrival. `RealDate` (only when FAKETIME is set) stamps the real time, as the reference's
  Thruster does.

## Divergences from the reference

Only the Rust port's documented ones, all inherited from the Sinatra snapshot:
- CSRF: `Sec-Fetch-Site`/`Origin` checks replace tokens (pages have no CSRF tags).
- Cookies: `session_token` written on sign-in and on the hourly refresh, not every request; `last_room`
  only when it changes; `_campfire_session` only for flash and the post-login redirect. Rails-compatible
  formats, so reference sessions stay valid.
- Jobs are in-process.
- ETags on room, messages and search pages hash their inputs, not the body.

Ported later from the Sinatra app (its commits after 69b4e3a, up to 8aac9d6): CSRF meta tags for the file
uploader, ETags on every 200, asset byte ranges, message show/edit in the full layout for frames,
room_not_found in the layout, no-cache on 204s, before-action heads as text/html, the sidebar's direct rooms
cached in Redis by membership, the bot boosts API, raw bodies for bot updates, and remote cable disconnects
(sign out, ban, deactivation, revoked membership), delivered here over Iodine's pub/sub.

Transport differences that aren't page content: Iodine sends `content-length` and `connection:
keep-alive` where Thruster chunks.

## Parity status

Checked against the reference on the box (`script/box-pair` + `script/compare`, the harness's DOM
normalizer, signed in as David):
- **66 pages identical**: every room page, `@message` anchors, messages pages (before/after/latest),
  message show and edit, boosts, involvement frames, searches (empty, results, none), users (self, others,
  bot, deactivated, banned), profile, sidebar, push subscriptions, account edit, custom styles, bots
  (list, new, edit), account users stream, room settings (open/closed new and edit, direct new and edit),
  autocomplete (HTML and JSON), webmanifest, service worker, join, session transfer, root and /rooms
  redirects, 404/robots, unknown path, non-numeric and inaccessible rooms (`script/paths.txt`).
- **Headers**: same on the bench routes, /up, an asset (body identical too), avatar, 404 and sign-in.
- **24 write flows** (`script/flows`): same status and redirect on every step; pages afterwards differ only
  in times and random values (join code, bot key).
- **Cable frames** (`script/cable_frames.rb`, 11 frames: welcome, 7 confirmations, the posted message,
  unread and read-room broadcasts, typing): identical to the Sinatra app's, which match the reference's.
- **Playwright harness** (round 2, `parity/out/rage2` on the box, image from 91fbe7f; reference vs
  candidate, frozen clock, default seed, the whole inventory in 6 batches): **859 of 874 cells pass, 1
  allowed (pwa/manifest, as for the Rust port), 0 fail, 14 error.**

  | batch | cells | pass | error |
  |---|---|---|---|
  | auth, errors, welcome | 92 | 90 | 2 (auth/sign_in/rate_limited) |
  | rooms | 172 | 168 | 4 (rooms/show/busy/page_around_middle: a 500, fixed in fd721e0 and checked against the reference since) |
  | messages | 122 | 122 | 0 |
  | interactions | 182 | 182 | 0 |
  | account, users | 112 | 104 | 8 (account/edit/saved, users/profile/avatar_uploaded) |
  | search, realtime, bot API, autocomplete, PWA | 194 | 193 + 1 allowed | 0 |

  Open at the time: rate_limited, account/edit/saved and avatar_uploaded. Root causes found and fixed on
  branch `fix-network-idle`; see "The network-idle errors" at the end.

## Benchmarks

`bench/run-hetzner`, all suites, 3 runs alternating order (sinatra,rage / rage,sinatra / sinatra,rage),
4 processes each, YJIT on in both, 0 errors. Results: `/opt/campfire-perf/results/rage/yjit-sinatra-vs-rage-run{1,2,3}`
(copied to `results/hetzner/rage/`). Image `campfire-rage:app` built 04:31 (commit 4cf101b).

Requests/sec, median of 3 (c=16 ranges in brackets):

| | room | messages | sidebar | search | post | avatar | static css | /up |
|---|---|---|---|---|---|---|---|---|
| c=16 Sinatra | 2556 [2546-2579] | 6822 [6818-6837] | 4090 [4062-4158] | 4155 [4116-4158] | 1691 [1655-1693] | 10670 | 59060 | 23398 |
| c=16 Rage | 2483 [2476-2540] | 7752 [7696-7762] | 3922 [3099-4053] | 4053 [4017-4110] | 1428 [1416-1434] | 11538 | 202507 | 64978 |
| c=64 Sinatra | 2538 | 6553 | 4236 | 4113 | 1698 | 10474 | 58751 | 23005 |
| c=64 Rage | 2500 | 7707 | 3912 | 4030 | 1452 | 11419 | 212976 | 70479 |
| c=1 Sinatra | 721 | 1996 | 1193 | 1117 | 572 | 2835 | 14382 | 6084 |
| c=1 Rage | 690 | 2192 | 1109 | 1120 | 556 | 3114 | 37006 | 15375 |

For scale: rails-opt 458 / 699 / 750 / 677 / 263, DHH 241 / 413 / 552 / 435 / 273 (room/messages/sidebar/search/post).

Cable fan-out (medians): every client got every message in every run (30/30, 0 failed).

| clients | delivery p50 Sinatra | delivery p50 Rage | messages/s under load Sinatra | Rage |
|---|---|---|---|---|
| 100 | 3.3 ms | 3.2 ms | 546 | 910 |
| 500 | 5.3 ms | 4.2 ms | 180 | 312 |
| 1000 | 7.9 ms | 5.4 ms | 102 | 184 |

Upload (median total ms): Sinatra 131.7, Rage 141.3 (runs 42 / 141 / 141; noisy for both).
Memory: idle anon 165-169 MB (Rage) vs 185-186 MB (Sinatra); peak 1.77-1.85 GB vs 2.16-3.10 GB.
Cold start ~1.5 s both.

Reading: page routes are within a few percent of Sinatra (the view code is shared; Rage is ahead on the
messages page, behind on room/sidebar/search). Rage serves tiny responses (/up, static CSS) 3x faster: Iodine's
C HTTP layer. Cable fan-out is 1.7-1.8x higher throughput (Iodine's C pub/sub writes to sockets). Posting
is 16% slower than Sinatra: the next thing to profile (Sequel's prepared-statement path per write, and the
transaction wrapper).

An earlier run against the Sinatra image without YJIT is kept in `results/rage/old-sinatra-no-yjit/` and
isn't used.

## Optimization pass (Oct 6), after notes/elixir-rust-optimizations.md

Each change was measured with `ab-rage.sh` (fresh probe per measurement, 3 s warm-up, 8 s at c=16,
alternating order, 4-5 reps, medians) on the box with nothing else running, and kept only with the 66-page
diff and 24 write flows unchanged against the reference (`parity-check.sh`; with `CAMPFIRE_CHECK_CACHES=1`
for the caches, which re-renders every hit and logs mismatches: none). One commit each.

| # | Change | Commit | Effect (c=16 req/s, median) | Kept |
|---|---|---|---|---|
| 0 | Sequel prepared statements through `Database#execute` by name (no dataset clone or row hashes) | cd34c6b | post 1422 -> 1760, room 2491 -> 2911, sidebar 4005 -> 4943 | yes |
| 1 | Split pages on fragment markers by byte offset | 7734116 | room 2849 -> 3490, search 4838 -> 5323, messages +1.7% | yes |
| 2 | Keep each page segment's deflate block (+ one CSRF meta token per process) | c83ab7b | room 3483 -> 5031, search 5483 -> 7869 | yes |
| 3 | Keep a body's gzip under the ETag middleware's MD5 | a98f212 | sidebar 5055 -> 7894, /up 77k -> 123k | yes |
| 4 | Read cache cleared on `PRAGMA data_version` change (checked once per fiber) and own commits | 807a8e1 | messages 10158 -> 13594, room 5004 -> 6290, search 7942 -> 11694, sidebar 7799 -> 10870, post flat | yes |
| 5 | Finished sidebar by read-cache generation + user + request inputs | 34bd5c8 | sidebar 10977 -> 37110 (3.4x) | yes |
| 6 | Finished messages page by ETag + Accept + encoding | 39dbd64 | messages 13544 -> 26148 (1.9x) | yes |
| 7 | Finished room and search pages by read-cache generation + page ETag (check mode) | d4a8b90 | room 6264 -> 18893 (3.0x), search 11877 -> 29949 (2.5x) | yes |
| 8 | WAL checkpoints off the request path | - | `wal_autocheckpoint=0` alone: post 1680 -> 1644. COMMIT (32% of a post) isn't checkpoints; it's the WAL writes, the same for Sinatra (both grow the WAL ~66 KB per post) | no |
| 9 | Post: build the new message's view from what the request holds; push job gets body/plain/creator; writes' bodies not kept gzipped | 251d43f | post 1683 -> 1894 | yes |
| 10 | Thruster's response cache for public responses (`X-Cache: hit`) | 3ce184c | avatar 19k -> 170k, static css 196k -> 213k | yes |

Changes in code shared with the Sinatra app (to port there): `lib/campfire/fragment_body.rb` (byte offsets,
`SegmentCache`), `lib/campfire/view.rb` (one CSRF meta token per process), `lib/campfire/etag.rb` and
`lib/campfire/compression.rb` (gzip kept by body digest; not for writes), `lib/campfire/messages.rb`
(`Messages.post`, `create_with_details`, `after_create(created:)`), `lib/campfire/support.rb`
(`Push.deliver_for_message` taking body/plain/creator), `lib/campfire/pages.rb` (`kept_response`, room and
search pages split into inputs and render). Rage-only: `db.rb` (Sequel path, read cache, generation),
`sidebars_controller.rb`, `messages_controller.rb` (kept pages), `response_cache.rb`. In Sinatra the read cache
and its generation would go into its own `db.rb`.

### Final run after the pass

`bench/run-hetzner --apps sinatra,rage --reps 3`, HTTP and cable suites, alternating order, 0 errors
(`results/hetzner/rage/final`; Rage image 3ce184c, Sinatra image of 06:14 with YJIT). c=16 req/s, median of 3:

| | room | messages | sidebar | search | post | avatar | static css | /up |
|---|---|---|---|---|---|---|---|---|
| Sinatra | 2577 | 6828 | 4105 | 4162 | 1653 | 10637 | 47577 | 23270 |
| Rage | 18820 | 25631 | 35034 | 28786 | 1537 | 179031 | 168084 | 108255 |
| Rage before the pass | 2483 | 7752 | 3922 | 4053 | 1428 | 11538 | 202507 | 64978 |

Post in this run was 1851 / 1537 / 1522 (Sinatra 1680 / 1653 / 1647); the A/B probes, on a fresh seed each,
measured 1422 -> 1894 over the pass. In the full suite the post route runs after the c=1 posts and the
read routes on the same database, and its COMMIT (the WAL writes, a third of a post) dominates.
Cable, 1000 clients: 194 messages/s delivered, p50 4.9 ms (Sinatra 104/s, 8.1 ms); 100% delivery.
Memory: idle 165-170 MB, peak 1.7 GB (Sinatra 185 MB, 2.0-2.1 GB).

Playwright round 3 on this image (`parity/out/rage3`): 863 of 874 cells pass, 1 allowed (pwa/manifest), 0
fail, 10 error: the same three network-idle states as round 2 (rate_limited, account/edit/saved,
avatar_uploaded). Responses to those requests are framed correctly and complete on the server, including
conditional and range requests on reused connections; the cause is still open.

## The network-idle errors (Oct 6, fixed on branch `fix-network-idle`)

The 10 errored cells from rounds 2 and 3 came from three separate bugs. I reproduced and fixed them on the Mac
(OrbStack, arm64). The reference parity image was built from the pinned reference 90b3300 as
`campfire-reference-90b3300`, because the local `campfire-reference` is acef0c7, whose
20261004 migration fails against the seed's frozen clock.

1. **account/edit/saved: a 404.** The account forms post to `/account.<id>` (`form_with model:
   Current.account`; a singular resource's path helper puts the record in the format slot). Rails routes
   that to accounts#update. Rage has no `(.:format)` and answered 404, so the flash never showed. Fix: map
   `/account.<anything>` to `/account` in `RequestMethod` (2b67d52).
2. **users/profile/avatar_uploaded: an empty 500.** The avatar form is multipart with `_method=patch`.
   `RequestMethod` parsed `_method` with `Rack::Request#POST` over Iodine's `rack.input`. Iodine's
   `#read(length, buffer)` copies into the buffer without clearing Ruby's cached coderange, so the JPEG
   part passed for ASCII. Rack's multipart parser kept its scan buffer UTF-8 and raised `ArgumentError:
   invalid byte sequence in UTF-8`, and Rage's fiber wrapper turned that into an empty 500. I reproduced
   it with bare Iodine 5.7.0 and Rack 3.2.7, no app code. Fix: parse the bytes already read from a
   StringIO (2b67d52). The account logo form had the same bug.
3. **auth/sign_in/rate_limited: CSS "in flight" forever, intermittent** (about 1 run in 4, 1–2 of 4
   cells). Every 401 sends `Link: rel=preload` for 16 stylesheets. Under the harness's libfaketime clock,
   Iodine stamped the frozen seed time (2026-03-02) as `Date`. Every asset Chrome had cached was therefore
   older than its 30-day max-age on arrival, so after the 401 Chrome fetched all 16 preloads from the
   network. The reference's Date comes from Thruster on the real clock, so its preloads came from cache:
   an instrumented harness proxy showed 0 network preloads before the reload for the reference and 16 for
   Rage. The `turbo-visit-control` reload then replaced the document, and Playwright sometimes never
   reported those preloads as finished; the proxy log shows every one completed upstream. Fix: `RealDate`
   stamps the real time when FAKETIME is set (4e6b2af). Evidence: frozen Date, 2 of 8 runs errored;
   unfaked candidate, 0 of 6; RealDate build, 0 of 6.

Also fixed (f840740): a failed sign-in for an unknown email skipped bcrypt. It answered in about 10 ms
against about 250 ms, which leaks which addresses have accounts. Rails' `authenticate_by` hashes the
password anyway, and the Rust port keeps that. **Sinatra has the same gap** (`apps/sinatra/lib/campfire/app.rb:170`).

Smaller difference, not fixed: `StaticFiles` ignores `If-Modified-Since` and answers 200 where Thruster
answers 304.

Local results on the final branch image: the three states pass on all 12 cells. A regression batch of
auth/**, errors/**, account/** and users/** passed 194 of 194 cells, with 0 fail and 0 error. Not rerun
on the box, and the full inventory wasn't rerun.

## Final parity (Oct 7, image from 4e6b2af, fix-network-idle merged)

Image `campfire-rage:app` 473bf7e81bc0 / candidate f0a828c360d6, built from 4e6b2af; every tracked file
matches (sha256 per path). Results: `results/hetzner/final-20261007-parity/rage-final*`.

| Seed | Cells | Pass | Fail | Error | Allowed |
|---|---|---|---|---|---|
| default | 874 | 873 | 0 | 0 | 1 |
| crowd | 25 | 25 | 0 | 0 | 0 |
| custom_styles | 33 | 32 | 1 | 0 | 0 |
| first_run | 16 | 0 | 0 | 16 | 0 |
| restricted | 8 | 8 | 0 | 0 | 0 |

- The 10 network-idle errors are gone on the default seed (rate_limited, account/edit/saved, avatar_uploaded pass).
- Allowed: pwa/manifest (the Rust port's documented JSON-escaping difference, allowlisted).
- Fail: pwa/manifest/custom_styles, server layer. Same cause: the manifest JSON-escapes the custom logo
  URL where Rails HTML-escapes it (`&amp;`). The allowlist only covers the default-seed state. Sinatra's
  9825d44 matches Rails instead; Rage doesn't have it.
- first_run: all 16 cells error with a 500 on `/first_run`, the same shared-view bug as Sinatra
  (`View#account_logo_path` on a nil account, lib/campfire/view.rb:72). Not fixed (held for JP).
