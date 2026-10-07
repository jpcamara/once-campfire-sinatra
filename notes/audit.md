# Audit: Sinatra, Rage and rails-opt against the Rails reference

Independent audit, Oct 6. Read-only. No app, note or result was changed and nothing ran on the box.
Small Ruby snippets ran locally to confirm logic (marker injection, MessageVerifier lengths,
sqlite `PRAGMA data_version`, FTS5 errors).

What was audited:
- apps/sinatra at main 75f85be.
- apps/rage at main 4e6b2af.
- apps/rails-opt at b868f70, diffed from acef0c7 (the working tree is clean).
- The reference: once-campfire-rust/reference, checked out at acef0c7.
- The rule: the Rust README's "Known differences" (once-campfire-rust/README.md:82-158).
- The harness: bench/run-hetzner and bench/loadgen.
- The results in results/hetzner, and notes/{sinatra,rage,rails-opt,elixir-rust-optimizations}.md.

Severity labels:
- **bug/security**: wrong or unsafe behavior.
- **undisclosed divergence**: an externally visible difference that no README entry covers and the
  notes don't mention.
- **disclosure gap**: the notes or the README mapping are wrong or incomplete.
- **nit**: minor.

Paths are relative to `~/Projects/campfire-perf/apps/<app>/` unless they say otherwise.

## Top findings

1. **Stored XSS in Sinatra and Rage (bug/security).** Uploaded HTML and SVG attachments are served
   inline, with the type the client declared, on the app's origin. Rails serves them as
   `application/octet-stream` attachments.
2. **Cross-site WebSocket hijacking in Sinatra and Rage (security).** `/cable` accepts any `Origin`.
   Rails and Rust answer a foreign Origin with 404.
3. **Bot API CSRF gap in Sinatra and Rage (security).** Bot API writes skip the Sec-Fetch-Site/Origin
   check when the user is signed in by cookie. Rails checks forgery unless the request was
   authenticated by bot key.
4. **Marker injection in Sinatra and Rage (bug).** User text containing `\x01<digits>\x02` is treated
   as a fragment marker. Room names, user names and the search query can trigger it. The result is a
   500, or another message's HTML spliced into the page. `GET /searches?q=%01999%02` is enough.
5. **Two smaller bugs in Sinatra and Rage.**
   - Sign-out keeps the device's push subscription.
   - Emails are lower-cased when saved but not when signing in. A user who joined as
     `Jane@Example.com` can't sign in by typing the same address.
6. **The read-route numbers measure the whole-response cache hit path, and no note says so.** The
   loadgen sends the same GET with no writes in between. Sinatra room served ~190k requests in 8 s
   with at most one miss per worker. Stock Rails, and DHH's 241/413/552/435, render every request.
7. **Benchmarked images are not the audited commits.** Every image was built from a working tree
   minutes before its labelled commit. Rage's benchmarked image predates 3ce184c, which is the label
   in the notes, and every Rage fix after it. The variants also run 4 web workers where stock Rails
   runs 3. Neither fact is in the notes.
8. **rails-opt is close to clean.** It has three undisclosed divergences:
   - `POST /searches` no longer runs the search first.
   - Sign-out no longer rotates `_campfire_session`.
   - Active Storage direct uploads now fail with 422.

   Its CSRF, read cache and kept responses check out.

---

## 1. Divergences

### Known item: the CSRF meta tag (Sinatra and Rage), confirmed

`lib/campfire/view.rb:41-46` defines `CSRF_TOKEN = SecureRandom.urlsafe_base64(64)`, one per process.
`views/layouts/application.erb:12-13` renders `csrf-param` and `csrf-token`.

The README says "Pages omit CSRF tags and fields". Rust removes the tags and ships an overridden
`file_uploader.js` instead: `crates/assets/overrides/models/file_uploader.js` drops the line that
reads the meta tag. Sinatra and Rage keep the tag so the stock `file_uploader.js` works. rails-opt
does what Rust does, and its `file_uploader.js` is byte-identical to Rust's override.

Effects:
- The same page differs in bytes depending on which worker served it.
- The page ETag doesn't include the token. That's acceptable only because the ETag is weak (`W/`).
- Nothing checks the token, so there's no security impact.

The Playwright harness strips both tags on both sides (`parity/capture/normalize.ts:95-99`), so parity
runs can't see this. Classification:
- Undisclosed divergence against the README.
- Disclosure gap in rage.md. Its Divergences section (rage.md:80) says "pages have no CSRF tags";
  rage.md:87 says the tags were ported.

### Sinatra and Rage (shared code unless noted)

| # | Difference | Evidence | README entry |
|---|---|---|---|
| D1 | CSRF meta tags, one random token per process | above | Not covered: the README says tags are omitted |
| D2 | `Sec-Fetch-Site: none` and unknown values are accepted; Rust rejects anything but same-origin/same-site. `Origin: null` passes; Rails and Rust reject it | sinatra `lib/campfire/app.rb:1258-1264`; rage `lib/campfire/web.rb:449-455` | Not covered: the CSRF bullet says writes accept same-origin and same-site and keep the Origin check |
| D3 | CSRF rejection is `422` with an empty body; Rails and Rust serve `public/422.html` | same lines | Not covered |
| D4 | Before-filter order: browser check, ban, CSRF, then auth. Rails: ban, auth, bot denial, CSRF, browser. An unauthenticated cross-site write gets 422 instead of a 302 to sign-in. An unauthenticated old browser gets the incompatible-browser page instead of the sign-in redirect | sinatra `app.rb:119-126`; rage `web.rb` plus each controller; Rust documents Rails' order at `once-campfire-rust/crates/campfire/src/concerns.rs:9-16` | Not covered |
| D5 | No `assume_ssl`/`force_ssl`/`DISABLE_SSL`: no HSTS, no `Secure` cookies, no https base URLs, no HTTP-to-HTTPS redirect. **No effect on the bench**: bench/run passes `parity/.env.reference`, which sets `DISABLE_SSL=true` for every app | grep finds no SSL handling in either app; reference `config/environments/production.rb:84-85` | Not covered (see Security S6) |
| D6 | `/cable` accepts any Origin; Rails and Rust answer 404 | sinatra `lib/campfire/cable.rb:19-32`; rage `config/routes.rb:123` mounts `Rage.cable.application` without its OriginValidator | Not covered (Security S2) |
| D7 | Bans are inserted for private and loopback IPs. Rails' `Ban` validates `ip_address_is_public`, so `bans.create!` raises and the ban fails | sinatra `lib/campfire/support.rb:501-511`; rage `support.rb:493`; reference `app/models/ban.rb:4-19`, `app/models/user/bannable.rb:31-35` | Not covered. Behind NAT or a proxy without X-Forwarded-For, one ban returns 429 to every user's writes |
| D8 | Boost content truncated to 16 characters. Rails stores the full string (SQLite ignores `limit: 16`) | sinatra `support.rb:576,579`; rage `support.rb:564,567` | Not covered. A bot boosting 17+ characters gets it cut |
| D9 | Emails lower-cased on join and profile update but looked up raw at sign-in | sinatra `support.rb:427,476` vs `app.rb:173`, `repo.rb:56-59`; rage `support.rb:415,464` | Not covered (bug, Security S7) |
| D10 | Sign-out ignores `push_subscription_endpoint`. Rails `SessionsController#destroy` deletes that subscription | sinatra `app.rb:234-242`; rage `app/controllers/sessions_controller.rb:23-31` | Not covered (bug, Security S5) |
| D11 | No `X-Request-Id`. Rails and Rust send one on every response | grep finds nothing in either app | Not covered |
| D12 | **Sinatra only:** no `Date` header on any response. Falcon builds `Protocol::Rack::Adapter` directly, and protocol-rack 0.23.0 has `headers.add('date', …)` commented out (`lib/protocol/rack/response.rb:65`). Rage's notes show why this matters: a wrong Date made Chrome refetch cached assets | `falcon.rb:18-20` | Not covered |
| D13 | Public-response cache per process: a request that reaches another worker gets `X-Cache: miss` where Thruster says `hit` | sinatra `lib/campfire/response_cache.rb`, identical in Rage | Not covered by the README. Disclosed in sinatra.md:48-49, missing from rage.md |
| D14 | Range GETs answer `X-Cache: miss`; Thruster and Rust answer `bypass` | `response_cache.rb:43-47` | Not covered (nit) |
| D15 | No `If-Modified-Since` handling for assets, `/robots.txt` or `/404.html`: 200 where Rails or Thruster answer 304. Sinatra's 304 is GET-only, so HEAD with If-None-Match gets 200 | `lib/campfire/static_files.rb`; sinatra `etag.rb:30` | Not covered. The rage.md:252 mention is the only disclosure |
| D16 | `return_to` is stored only for GET/HEAD; Rails stores it for any method | sinatra `app.rb:1174`; rage `web.rb:365` | Not covered (nit) |
| D17 | Missing routes that 404:<br>• Active Storage direct uploads, disk PUT, proxy routes and the short blob form<br>• **Rage:** `(.:format)` suffixes, the second verb of PATCH/PUT pairs, user ids other than `me` on profile and push paths, `DELETE /rooms/opens/:id` and `/rooms/closeds/:id`<br>• **Rage:** `GET /cable` without an upgrade answers 426 (Rails 404); a missing asset answers plain-text "Not found" | sinatra routes in `app.rb`; rage `config/routes.rb` | Not covered. rage.md:67-69 discloses only the format suffixes |
| D18 | The turbo-stream for a message create has different whitespace | sinatra.md:102 | Disclosed in notes, not README (nit) |
| D19 | **Rage:** a sidebar cache hit drops the `Link: rel=preload` header. Sinatra fixed this in 36ec177, along with avatar Vary and the avatar redirect's security headers; none of it was ported. The bench requests the sidebar as a full page, so every measured hit lacks the 16-stylesheet header | rage `app/controllers/sidebars_controller.rb:13-24` (only `render_layout`, `web.rb:287`, sets Link) | Not covered. rage.md:106 "headers same on bench routes" predates the cache |
| D20 | **Rage:**<br>• ETag is MD5 and only on 200s; Rack 3 uses SHA-256/32 on 200 and 201<br>• Avatar and logo ETags are MD5 of `users/id-updated_at`<br>• No default Cache-Control on bot API JSON, autocomplete JSON, unfurl JSON or push create<br>• Middleware 304s keep Content-Type | rage `lib/campfire/etag.rb:24`, `support.rb:38,71` | Not covered. Playwright compares only content-type, location, cache-control, content-disposition and vary |
| D21 | **Rage:** Iodine's defaults cap bodies at 50 MB, header lines at 8 KB and WebSocket messages at 256 KB. Rails and Thruster have no body cap; Rust caps non-upload bodies at 16 MiB | rage-iodine `http.h:35` | Not covered. Attachments over 50 MB fail |
| D22 | **Rage:** a malformed form body containing `_method` raises inside `RequestMethod` and returns an empty 500; Rails returns 400. Bad requests are empty 400s with no headers | rage `lib/campfire/request_method.rb:63-65` | Not covered |
| D23 | **Rage:** `Content-Length` and `Connection: keep-alive` where Thruster chunks | rage.md:93 | Disclosed in notes, not README (nit) |
| D24 | **Sinatra:** WAL checkpoints in a separate, unsupervised process (`bin/checkpoint`). If it dies, the WAL grows without bound, because app connections set `wal_autocheckpoint=0` | `bin/start:20`, `lib/campfire/db.rb:42` | Not visible in responses. Robustness gap, not disclosed |
| D25 | Cookies written only on change; jobs in-process; ETags from inputs | sinatra.md:36-49, rage.md:77-85 | Covered by the README's Cookies, Jobs and Caching bullets |

The README's Caching bullet says Rust's ETags "hash cached page parts". Sinatra and Rage hash a
list of inputs instead (`page_etag`, rage `web.rb:272-274`). That is a different mechanism. Its
correctness depends on the input list being complete, which is checked in section 2.

### rails-opt

| # | Difference | Evidence | README entry |
|---|---|---|---|
| R1 | Sec-Fetch-Site instead of tokens; no CSRF tags or fields; Rust's `file_uploader.js` | `app/controllers/concerns/same_origin_forgery_protection.rb:13-24` | Covered (CSRF). Matches Rust's `kit/src/ctx.rs:204-236` |
| R2 | `session_token` re-signed hourly, `last_room` on change, session cookie only on change | `authentication.rb`, `tracked_room_visit.rb`, `lib/rails_ext/changed_session_cookie_store.rb` | Covered (Cookies), except R5 |
| R3 | 304s on revalidation; kept pages carry stock's Rack::ETag value | `kept_responses.rb:60-77` | Covered (Caching), and the ETag equals stock's |
| R4 | **`POST /searches` no longer runs the search query.** Stock ran `before_action :set_messages` on every action, and `last_page_of` loads eagerly. Scenario: search for `OR` (FTS5 syntax error).<br>• Stock: POST returns 500 and nothing is saved.<br>• rails-opt: POST returns 302 and `OR` is saved to recent searches.<br>• Both: the follow-up GET returns 500, and in rails-opt the saved `OR` stays in the recent-searches list | `app/controllers/searches_controller.rb:4-13` vs stock `:2` | **Undisclosed divergence.** The README's Search bullet is Rust's literal-terms fix, which rails-opt didn't take |
| R5 | **Sign-out doesn't rotate `_campfire_session`.** `reset_session` → `Session#destroy` → `load_session` records the new empty hash as "loaded", so `commit_session?` sees no change and writes no cookie. The browser keeps the old cookie (old `_csrf_token`, flash, `return_to_after_authenticating`). Authentication is unaffected | `lib/rails_ext/changed_session_cookie_store.rb:9-19` | **Undisclosed divergence.** Rust "deletes [the session] when empty"; this neither writes nor deletes |
| R6 | **Active Storage direct uploads return 422.** `ActiveStorage::BaseController` still uses token forgery protection, and no page hands out a token any more. Rust checks Sec-Fetch-Site there (`crates/campfire/src/active_storage.rs:455`). The UI doesn't use direct uploads | `application_controller.rb:2` includes the concern only in app controllers; `forms_helper.rb:7-9` | **Undisclosed divergence** (API only) |
| R7 | A kept page's `Vary: Accept` depends on which request filled the entry. A Turbo visit and a full reload share a key, and kept 304s carry `Vary: Accept` that stock's in-controller 304 doesn't | `kept_responses.rb:48-49` | Nit (bodies identical) |

X-Cache, Date and the public-response cache don't change in rails-opt: Thruster is still in front.

---

## 2. Cache correctness

### Findings

**C1. bug/DoS (Sinatra and Rage): StaticFiles keeps one copy per path spelling.**
`lib/campfire/static_files.rb:17-18` stores `@entries[path] ||= load(path)` under the raw unescaped
`PATH_INFO`. `load` normalizes the path with `expand_path`. So `/assets//x`, `/assets/./x` and
`/assets/a/../x` each keep their own copy of the body plus a gzip of it, forever.

Scenario: unauthenticated requests for about 1,000 spellings of the 2.1 MB lexxy source map hold
2-3 GB per worker. Not tested through Falcon or Iodine path handling. Neither is known to normalize
`//` or `/./`.

**C2. bug (Sinatra and Rage): ResponseCache buffers whole public bodies before deciding to keep them.**
- `response_cache.rb:31-38` reads every `public` response into one String. `store` then drops it if
  it's over 1 MB. Disk blobs are `max-age=3600, public` (sinatra `app.rb:978`).
- Compression then gzips the whole body again in memory (`compression.rb:43-48`).
- Scenario: each concurrent plain GET of a 500 MB video holds about 1 GB in a worker. Rails,
  Thruster and Rust stream these.
- The `@vary` index (`response_cache.rb:79`) is never pruned, even when entries are evicted. So
  `/assets/app.css?n=1..∞` grows it by about 2 KB per URL per worker.
- The lifetime regex reads `s-max-age`, but the directive is `s-maxage` (nit).

**C3. Memory (Sinatra and Rage): whole-page caches are capped by entry count, not bytes.**
- Rage caps: kept pages 512 (`lib/campfire/pages.rb:89`), sidebars 1,024, segment cache 2,048.
- The keys include client-controlled values: User-Agent, Accept, Turbo-Frame, the query, and the
  gzip flag.
- Scenario: one signed-in user cycling User-Agents fills 512 messages-page entries of up to about
  450 KB each, about 230 MB per worker.
- The bench never sees this, because it sends one key per route.

**C4. Memory (rails-opt): loosely bounded caches.**
- Per process: KeptResponses 128 MB of body bytes, with keys (full UA strings) uncounted;
  GzipCache 64 MB; ReadCache 5,000 entries with no byte cap; FragmentCacheStore 10,000 local copies.
- Each Resque worker also gets its own ReadCache.
- Worst case is over 1 GB above stock across four processes.
- Both byte-capped stores call `shift` on an empty hash if one body exceeds the whole cap. That's
  unreachable in practice.

**C5. nit (Sinatra and Rage): Redis direct-room keys pile up.**
- The key is `…/memberships/#{id}-#{updated_at}`, with no TTL and no Redis `maxmemory`.
- Rails with cache versioning reuses one key per membership and keeps the version inside the entry.
- Every DM post leaves a new key for each recipient.
- Behavior matches Rails (same stale-unread semantics). Redis memory doesn't.
- Evidence: sinatra `app.rb:1468`, rage `pages.rb:205`, `bench/redis-6390.conf`.

**C6. nit: the cache keys for gzip handling ignore q-values.** `gzip;q=0` counts as accepting gzip in
Sinatra and Rage (rage `pages.rb:94`, `compression.rb:28`). Rails' Rack::Deflater honors the q-value.

**C7. nit: MD5 digests.** The kept-gzip caches use MD5 in Sinatra and Rage (`compression.rb:32-33`)
and in rails-opt (`lib/rails_ext/gzip_cache.rb:32`) for non-kept pages. A chosen-prefix collision in
a page's content is impractical. SHA-256 would match Rack 3 and Rust.

**C8. nit (Sinatra and Rage): Host rotation evicts.** Kept-page and fragment keys include `base_url`
from Host/X-Forwarded-Host. A signed-in client rotating Host can evict other users' entries. Nothing
leaks, because every lookup also keys on the host.

**C9. nit (rails-opt): the data_version connection has no busy_timeout.** `config/initializers/read_cache.rb:58-65`
opens it with no busy_timeout. A SQLITE_BUSY there would raise in `executor.to_run`, which is a 500.
Not observed; `PRAGMA data_version` rarely needs a lock.

### Per-cache check

"One user's page to another" means: does the key include everything user-specific (user, role,
memberships, unread, involvement, bans, account settings, custom styles, UA-dependent markup,
Accept-Encoding, Turbo-Frame, query, flash, host)?

| Cache | One user's page to another? | Cross-process staleness | Time-dependent output | Memory |
|---|---|---|---|---|
| **Sinatra `DB::ReadCache`** (`lib/campfire/db.rb:86-128`) | Keyed by SQL + binds | `PRAGMA data_version` on the reader, checked at the start of every request (keep-alive included, `app.rb:120`), cable connect and command, and job; cleared after own commits and rollbacks (`db.rb:153-166`). OK | Time binds are part of the key | 8,192 entries, LRU |
| **Rage `ReadCache`** (`lib/campfire/db.rb:114-160`) | Same | "Once per fiber" is once per request: Rage's FiberWrapper creates a new fiber per request, and cable messages and jobs get their own. OK | Same | 8,192 |
| **rails-opt `ReadCache`** (`config/initializers/read_cache.rb`) | SQL + bind values | data_version on its own never-writing connection, in `executor.to_run`: every request, Resque job and cable action. Own writes bump before and after each statement and on commit/rollback. Reads in transactions aren't cached. A result is stored under the generation at which its read started, so a race gives a miss, never a stale hit. OK | Same | 5,000 entries (C4) |
| **Kept room/search/messages pages** (sinatra `kept_response`; rage `pages.rb:91-107`; rails-opt `kept_responses.rb:47-58`) | Sinatra/Rage key: generation + page ETag (base URL, UA, user id, updated_at, role, room, account updated_at and name, invitation, DM names, message ids and updated_at, flash) + Turbo-Frame + Accept + gzip. rails-opt key: generation + user id + base_url + fullpath + format + frame + UA (+ `last_room` for search). Everything else on these pages comes from the database, so the generation covers it. Membership checks run before the lookup. Every write that changes the logo, custom styles or join code touches `accounts.updated_at`; boosts touch the message. The bell is a lazy frame. OK | Generation | None: times render client-side (`local_datetime_tag`, reference `app/helpers/time_helper.rb:2`), the transfer link and QR code are on uncached pages, and disk URLs aren't kept | C3, C4 |
| **Messages page, Rage** (39dbd64) | Key is the ETag, which covers every message version and request input. No generation, but it only holds shared message fragments, like Rails' fragment cache | OK | – | 512 |
| **Kept sidebar** (sinatra `b249617`; rage `sidebars_controller.rb:12`; rails-opt `render_kept`) | generation + user + base_url + UA + frame + Accept. Unread state, DMs and memberships are database state. Flash bypasses the cache. OK, except the Rage Link header (D19) | Generation | – | 1,024 (Rage) |
| **Redis DM fragments** | membership id + updated_at | Shared Redis | – | C5 |
| **Message fragments (Sinatra/Rage, per process)** | (message id, updated_at, host) | A creator rename leaves workers disagreeing until eviction. Rails shares one copy in Redis, but it is also stale on rename | – | 5,000 |
| **FragmentCacheStore (rails-opt)** | Versioned Rails keys; local copy used only while its version matches. The app never deletes or clears the store, so stale local copies after a delete can't arise | OK | – | 10,000 |
| **Gzip caches** (Sinatra/Rage segment/run/body; rails-opt GzipCache) | Content-addressed (digest + content type) | – | – | Bounded (C7 nit) |
| **ResponseCache (Sinatra/Rage)** | Only GET/HEAD `public` responses with positive max-age; Set-Cookie stripped; keys on host, path, query and the Vary header values. Disk URLs stay cached up to an hour after their signature expires, the same as Thruster | Per process (D13) | Same as Thruster | C2 |
| **Verified-signature cache (Sinatra)** (`lib/campfire/rails_compat.rb:41-59`) | Keyed by the exact signed string, stored only after a wrong-length reject and a constant-time compare (`:49`). Purpose and expiry re-checked on every hit (`unwrap`, `:56`). The session row is still looked up, so sign-out and revocation work. A forged, expired or wrong-purpose token can't hit it. OK. Rage has none | – | Expiry re-checked | 4,096 per verifier |
| **StaticFiles** | – | Digested assets | – | C1 |

`CAMPFIRE_CHECK_CACHES=1` check mode runs in all three apps, and the notes report it clean. It
compares a hit with a fresh render in the same process at the same generation. So it can catch an
incomplete key. It can't catch a missing invalidation: a stale database read gives a stale render
too. The invalidation logic above was checked by reading the code instead.

---

## 3. Security

### Findings

**S1. bug/security, high (Sinatra and Rage): stored XSS through attachments.** Confirmed by reading.

Evidence:
- `lib/campfire/uploads.rb:122-133`: `identify` keeps the client's declared type unless the bytes are
  JPEG, PNG, GIF, WEBP or BMP.
- `redirect_to_disk` (sinatra `app.rb:1150-1155`, rage `web.rb:341-347`) passes `blob.content_type`
  through, with `inline` unless `?disposition=attachment`.
- The disk route serves that type (sinatra `app.rb:973-979`).
- Nothing implements Rails' `content_type_for_serving` / `forced_disposition_for_serving`, which
  serves text/html, SVG, XML and similar as `application/octet-stream` with `attachment`.
- Rust implements both (`crates/storage/src/content_types.rs`: SERVE_AS_BINARY, ALLOWED_INLINE).

Scenario:
1. A member attaches `x.html` (or `.svg`) declared `text/html` to a message. The signed blob id is
   in the message HTML.
2. They post `/rails/active_storage/blobs/redirect/<signed_id>/x.html` without the disposition query.
3. A signed-in victim clicks it, gets a 302 to the disk URL, and the file renders inline as HTML on
   the app's origin.
4. Its script sends same-origin writes, which pass Sec-Fetch-Site, as the victim. An admin victim
   means account takeover.

**S2. security, medium (Sinatra and Rage): `/cable` checks no Origin.**
- Sinatra `cable.rb:19-32` upgrades any Origin.
- Rage mounts `Rage.cable.application`, whose router path bypasses `Rage::OriginValidator`
  (`config/routes.rb:123`; `app/channels/application_cable/connection.rb:6-13` checks only the cookie).
- Rails production allows only the same origin as the host (no `allowed_request_origins` in
  reference config). Rust rejects a foreign Origin (`crates/cable/src/server.rs:133-250`).

Scenario: a page on a sibling subdomain (same site, so SameSite=Lax cookies go with the handshake)
opens `/cable` as the victim. It can then:
- Subscribe to the victim's rooms' streams and read messages live.
- Watch presence and typing.
- Send typing events and mark rooms read as the victim.

Fully cross-site pages are stopped by SameSite=Lax.

**S3. security, low-medium (Sinatra and Rage): bot API writes skip CSRF for cookie sessions.**
- The bot POST, PUT/PATCH and DELETE routes never call `verify_same_origin!` (sinatra
  `app.rb:645-706`; rage `app/controllers/bot_messages_controller.rb:18-78`).
- `bot_room!` tries the session cookie first and then ignores the key in the URL (sinatra
  `app.rb:1269-1279`, rage `pages.rb:5-15`).
- Rails: `protect_from_forgery … unless: -> { authenticated_by.bot_key? }` (reference
  `app/controllers/concerns/authentication.rb:10`). So a cookie-authenticated bot write without a
  token fails.

Scenario: a same-site page runs
`fetch("/rooms/1/x/messages", {method: "POST", body: "hi", credentials: "include"})` and posts as the
victim. Over plain HTTP, a browser that sends no Sec-Fetch-Site can do the same.

**S4. bug, medium (Sinatra and Rage): fragment-marker injection.** Confirmed by running the real
`fragment_body.rb`.
- `FragmentBody.from` (`lib/campfire/fragment_body.rb:70,82-93`) splits every room, search and
  messages page on `/\u0001(\d+)\u0002/`.
- `HTML.h` is `CGI.escapeHTML` (`lib/campfire/html.rb:15`), which leaves control characters alone.
- The template marker is emitted at `view.rb:163`.
- Text a user controls in the page shell: room names, user names (DM titles, nav), account name or
  styles (admin), and the search `q` echoed in `views/searches/footer.erb:10`.

Results:
- An out-of-range index puts nil in the parts list and raises NoMethodError, so the page is a 500.
  Repro: `GET /searches?q=%01999%02`. A room named `"\u00017\u0002"` 500s for every member, and a
  user renamed that way breaks every DM page with them.
- An in-range index splices that cached fragment's HTML into the attribute or title.

Rails renders these fine. Rust records parts while rendering, so nothing can collide.

**S5. bug/privacy (Sinatra and Rage): sign-out keeps the push subscription (D10).** On a shared
computer, the device keeps getting the user's message text as notifications after sign-out. Rust
implements the deletion (`crates/campfire/src/controllers/sessions.rs:83-85`).

**S6. security for real deployments (Sinatra and Rage): no HTTPS mode (D5).**
- Behind a TLS proxy without `DISABLE_SSL`, `session_token` has no `Secure` flag and there's no HSTS.
- The README's "reject missing Sec-Fetch-Site over HTTPS" never fires unless the proxy sends
  `X-Forwarded-Proto`, because `request.scheme` is http (sinatra `app.rb:1261`, rage `web.rb:452`).
- No bench effect (D5).

**S7. bug (Sinatra and Rage): email normalization (D9).**
- `Jane@Example.com` joins, then signing in with the same text returns 401.
- `Bob@x` and `bob@x` are separate accounts in Rails and collide here.

**S8. undisclosed divergence (Sinatra and Rage): CSRF acceptance is wider than the spec (D2).**
`Sec-Fetch-Site: none` (a typed URL or bookmark can't produce a POST, so this is low risk) and
`Origin: null` (sandboxed iframes, some redirects) are accepted.

### Verified OK

**CSRF**
- rails-opt matches the README and Rust exactly:
  - GET and HEAD skip the check.
  - The Origin check is kept, and `null` fails.
  - same-origin and same-site pass; cross-site and none fail.
  - A missing header passes only when `!request.ssl? && !force_ssl`.
  - Bot-key requests and PwaController skip, as in stock.
- Sinatra and Rage: every non-GET route except the bot API calls `verify_same_origin!`.
- Rage's `_method` override applies only to POST, as Rack's does. A GET can't become a write.
- The `/account.<id>` mapping is harmless.

**Cookies and signatures**
- Sinatra and Rage MessageVerifier: wrong-length signatures rejected (the earlier bug is fixed),
  `OpenSSL.fixed_length_secure_compare`, purpose and expiry checked.
- AES-GCM requires a 12-byte IV and a 16-byte tag.
- Verified-signature cache: section 2.

**bcrypt**
- Sinatra 75f85be and Rage f840740 compare unknown and inactive emails against a precomputed cost-12
  digest (sinatra `app.rb:167-176`), the same cost as stored digests.
- Neither fix is in the benchmarked images (section 4, B6). It doesn't affect bench routes.

**Authorization**
- Sinatra and Rage route checks match the Rails before-actions:
  - Room scoping by membership.
  - `room_scope` per room type.
  - `ensure_can_administer` (account, bots, custom styles, join code, logo, users, bans).
  - Message administer checks.
  - Boosts via reachable messages.
  - Push subscriptions scoped to the user.
  - Autocomplete via membership.
- rails-opt adds and reorders no before-action; KeptResponses runs inside the action, after all of them.

**Cable**
- Room channels authorize by membership.
- The Turbo streams channel refuses `:messages`.
- Revoked, banned and deactivated users are disconnected across processes (Sinatra via Redis, Rage
  via Iodine pub/sub).
- Rage's welcome, ping, confirm, reject and disconnect frames match Rails.

**Bans and rate limits**
- Banned-IP check runs on non-GET/HEAD only, as in Rails. The binary-encoded IP bind bug is fixed in
  both apps.
- `remote_ip` trusts X-Forwarded-For only from trusted proxies.
- Sign-in rate limit uses shared Redis INCR/EXPIRE and fails open, like Rails.

**Uploads**
- Storage keys are server-generated; filename basename only.
- Disk and variation keys are signed.
- StaticFiles blocks traversal with a prefix check.
- Unfurl pins a public IP at each redirect.

---

## 4. Benchmark method

The harness diff is small and every change is marked. Everything else in it was checked and is fair:
- Every variant runs on CPUs 4-7 with the loadgen on 0-3, host network, a fresh seed copy and a fresh
  container per rep.
- All images preload jemalloc and run YJIT, with no GC tuning and no memory limits.
- In-container Redis, Thruster, Resque and Sinatra's checkpointer all share the app's 4 CPUs.
- Loadgen, lib and report have no local edits.
- Every claimed number checks against the raw JSONs (table below).

### Findings

**B1. undisclosed bias, high: the read routes measure whole-response cache hits.**
- The loadgen sends the same GET every time: same path, same cookie, `accept-encoding: gzip`, no
  User-Agent, no If-None-Match, no Turbo-Frame (`bench/loadgen/src/main.rs:309-316`).
- All read routes run before any write (`bench/run-hetzner:214-223`).
- The 2 s warm-up at c=4 fills every worker's kept-response cache.
- So after at most one miss per worker:
  - Every c=1/16/64 room, messages, sidebar and search request is a hash lookup plus auth.
  - Sinatra room at c=16: 189,714 requests in 8 s. rails-opt: 22,711.
- In real use, any commit on any connection clears every kept page in every process. That includes
  posts in any room, `connected_at` presence updates and the hourly session refresh.
- `tools/mixed.sh` (reads at c=16 while another user posts 0/20/100 per second) exists, but no
  mixed-load result is in the notes or results/.

The comparison with the Elixir PR #5 and Rust numbers is fair, since they cache the same way and
elixir-rust-optimizations.md:43-44 says so for Elixir. The comparison with stock Rails and DHH's
table is not like-for-like work. sinatra.md, rage.md and rails-opt.md don't say so.

**B2. disclosure gap, medium: 4 web workers against stock's 3.**
- bench/run gives stock Rails ceil(4×0.666) = 3 Puma workers and `JOB_CONCURRENCY=3`
  (`run-hetzner:112-115`).
- The HETZNER CHANGE at `:117-118` gives every other app `WEB_CONCURRENCY=4`, including falcon-fixes
  and rails-opt.
- `env.txt` shows both values (`WEB_CONCURRENCY=3 … WEB_CONCURRENCY=4`). Docker keeps the last.
- The final tables quote DHH's numbers from his machine. The same-box stock baseline exists and isn't
  in them: `results/hetzner/baseline-acef0c7`, c=16 223/373/463/366/185.
- elixir-rust-optimizations.md:45 says the harness was "patched only for the box".

**B3. disclosure gap, high for provenance: benchmarked images are not the labelled commits.**
Image creation times from `env.txt` (+02:00) against git commit times (-04:00):

| Run | Image built (EDT) | Labelled as | Actual position |
|---|---|---|---|
| rage/final, sinatra-pass2-final, rails-opt-pass2-final (Rage) | 06:59:51 | 3ce184c (07:07:52) | Built 8 min before 3ce184c was committed, after 251d43f. Avatar 178-181k req/s shows the response cache was in the image, so it was built from an uncommitted tree. It has none of 2b67d52, f840740 or 4e6b2af |
| sinatra-pass2-final (Sinatra) | 16:42:41 | 9825d44 (17:38) | 26 s after 2d97a37 (16:42:15), before b99c0c9 (16:47, "messages +8%"). Could be 2d97a37 plus uncommitted b99c0c9 work |
| sinatra-pass2-final-sinatra | 18:43:06 | 3591f56 (18:46:44) | Built 3.5 min before the commit. 75f85be (bcrypt) came later |
| rails-opt-pass2-final | 12:21:11 | b868f70 (12:20:45) | Matches |

Also: `env.txt` records `rust HEAD:  (dirty: 0 files)` with no hash, so the harness and loadgen
versions on the box aren't recorded.

None of this changes a number. It means "image X" in the notes is a label, not a build provenance,
and the audited HEADs of Sinatra and Rage were never benchmarked.

**B4. small bias toward Sinatra and Rage on post: push work.**
- `neuter_deliveries` (`run-hetzner:127-135`) points every push endpoint at `https://127.0.0.1:9/...`.
- Sinatra (`lib/campfire/support.rb:215-218`) and Rage (`support.rb:147,200`) skip a non-permitted
  endpoint before the badge `COUNT(*)`.
- Rails and rails-opt compute `user.memberships.unread.count` in `Push::Subscription#notification`
  (reference `app/models/push/subscription.rb:17`) before the resolver rejects the address. That's up
  to 3 extra queries per post in the hq room, plus Resque job work.

**B5. method, conservative: post runs on a database each app grew differently.**
- c=16 posting runs after the c=1 posts into the same room. Sinatra adds about 16k messages before
  its c=16 run; rails-opt about 1.6k.
- This penalises the faster apps. Only rage.md:208-210 mentions it.

**B6. disclosure gap: Rage outliers hidden by medians.**
- Room at c=16: 10,208 in `sinatra-pass2-final/run-2/rage-1.json`, against 18,500-18,900 in the
  other runs.
- Messages: 19,526 and 20,474 against about 25,500. Sidebar: 27,984. Static CSS: 164k against 210k.
- Latency in the slow run is uniformly about 1.7× higher with a tight p99. That looks like uneven
  connection spread across Iodine workers, but it isn't proven.

**B7. nits.**
- sinatra.md:174 says 2 job threads per worker; the harness passes `JOB_CONCURRENCY=3`, which
  `support.rb:146` honors.
- rage.md:144 quotes pass-1 rails-opt numbers.
- rage.md:155's Sinatra peak, 2.16-3.10 GB, is cgroup peak; the JSONs give 2,187-3,114 MB.
- Rage's `/up` (107k) and CSS (209k) may be loadgen-bound on 4 cores.
- bench/report crashes without a reference app. Disclosed.
- The Rust repo pins reference 90b3300; the local checkout and all bench images are acef0c7, which
  includes #292 "Preload only uncached messages and reduce rendering overhead". Rage's Playwright
  fixes were checked against a 90b3300 build (rage.md:222-224). DHH's README table was updated in the
  reference at 345e637, just before acef0c7, so it is presumably measured on that code. Not stated.

### Claimed against computed

Medians were recomputed from every JSON.

| Note table | Result |
|---|---|
| sinatra.md final table (three apps), c=64, c=1, cable, memory | exact |
| sinatra.md checkpoint tables (c=1/16/64, cable, upload, idle/peak) | exact |
| rage.md first table, cable, upload, memory | exact |
| rage.md final table (per-run posts 1851/1537/1522; cable at 1000 clients) | exact |
| rails-opt.md pass-1 final (352 → 458; +30/21/20/23/9%) | exact |
| rails-opt.md pass-2 final, c=64, c=1, cable | exact |

All runs had 0 errors, and every bench route returned only 200s. Not checkable locally: the
per-commit A/B tables and the "Sinatra before the pass" row, whose results are only on the box.
No result file is newer than the notes, so nothing from the rerun in progress is mixed in.

---

## 5. Analysis accuracy (notes/elixir-rust-optimizations.md)

**A1. analysis error, medium: Rust gains credited to commits that came before the baseline.**
- "How Rust went from 1,566 to 26,796 … in a week" (lines 52-66) lists "786a74d and earlier pass"
  (WAL checkpoints, LTO, jemalloc) and the "cable pass (4e77f67…)".
- Both are ancestors of 3fe9f61, the 1,566 baseline, so they are inside it, not part of the gain.
- The same goes for e89cc43 and fa1deb9 in candidates 10 and 11 (which only matters if read as part
  of the week).
- The remaining rows, abcaa09 through 2f755bf and 266f547, are after the baseline.

**A2. disclosure gap: the doc is stale and not marked.**
- It was written before the optimization passes.
- "Have it" still says no/no/no for items now done in all apps.
- Lines 145-149 say rails-opt hasn't taken the CSRF change; pass 2 did (e70715f).
- The numbers table shows pre-pass figures.

**A3. nit: the source of the commit ids is wrong.** Lines 25-27 cite "the same README table" for
3498c18, 504428a and 1ea6d6f. The Rust README names no commits. They come from the Elixir pr5
README, whose Rails row (216/384/503/380/267) differs from the Rust README's (241/413/552/435/273).

**A4. nit: two figures don't trace to their sources.**
- "Rust: recorded parts −14–16% CPU" (line 116). The nearest sources are room −12% and messages −7%
  (`page-parts-hot-path-20260930`), or −24% with inline reads (`inline-reads-recorded-parts-20260930`).
- "Sequel's prepared statements … cost ~24%" (line 140) is the whole database share in the profile
  table (line 95), including SQLite steps and the account query.

**A5. nit: the index claim depends on the reference version.** "(room_id, created_at) index: in the
reference schema already" (line 138) is true for acef0c7 (`db/schema.rb:104`). It's false for
90b3300, the commit the Rust repo pins and against which Rust's `aa3b894` added the index on boot.

**Verified:**
- The README and M3 tables match `tables-rps.md` exactly.
- Elixir gzips at level 1 (`lib/campfire/http_compression.ex:6`); room 33,082 vs 24,233 bytes.
- Go's sidebar is 9,462 bytes vs about 30.9k.
- 3fe9f61 had CSRF tokens.
- Every Rust commit subject and "measured there" figure matches its bench report or
  `plans/overnight-report.md`.
- Every Elixir round commit is on pr5 with matching subjects and effects.
- CPU per request: 0.11 / 0.23 / 1.56 / 1.61 / 8.7 ms.
- The character-offset scan bug was real (Sinatra e3f5ecc).

---

## Verified OK (summary)

- **No cross-user leak in any whole-response or read cache.** Every key that serves a user-specific
  page includes the user, the database generation and every request input the page reads.
  Authorization runs before every lookup.
- **Cross-process invalidation is correct in all three apps.** `PRAGMA data_version` is checked at
  the right times on the right connection, own commits clear or bump, and there's no keep-alive
  staleness.
- **No server-rendered time-dependent output on cached pages.**
- **Cookie crypto is sound.** Signature checks are constant-time with length checks; GCM IV and tag
  lengths are enforced; purpose and expiry are checked; the verified-signature cache can't be hit by
  forged or expired tokens.
- **rails-opt CSRF and cookie behavior** match the README, except R4-R6.
- **bcrypt unknown-email fix** is in both apps at the right cost.
- **Every benchmark number in the notes matches its raw JSON.**
