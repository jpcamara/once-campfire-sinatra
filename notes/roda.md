# Campfire on Roda + Sequel (Falcon)

Repo: github.com/jpcamara/once-campfire-roda (local: apps/roda). Image: campfire-roda:TAG, labelled
with its commit (tools/build-roda.sh). Ports on the box: probe 4790, pair 4794 (reference) / 4796 (app),
Redis 6393, parity 4411/4412. Containers roda-*.

## Starting point

A snapshot of the Sinatra app at debdb4f (its HEAD with every audit fix, Elixir-style page assembly,
the kept sidebar and per-ETag messages page, the data_version read cache, the public-response cache,
the posting work and the CAMPFIRE_CACHING=rust switch). The first commit in the repo is that tree
unchanged (d8bc719), so the Roda conversion reads as one diff.

## What changed, and why

- **HTTP layer: Roda's routing tree.** The 84 Sinatra routes became one handler method each (the
  route bodies unchanged), dispatched from a routing tree grouped by first segment (`r.on "rooms"`,
  `"account"`, `"users"`, `"messages"`, `"session"`, `"searches"`, `"rails/active_storage"`). Paths
  match whole, as Sinatra's anchored patterns do: Roda wraps each regexp in `\A/(?:…)(?=/|\z)` and a
  terminal verb matcher needs the rest of the path consumed. Within a branch the first match wins,
  so rooms#show's any-segment catch-all comes last in `rooms`.
- **Plugins:** `all_verbs`, `head` (HEAD routes as GET, empty body), `cookies`, and `Rack::MethodOverride`
  via `use` (forms send `_method`). Nothing else.
- **A small response plugin (`Responses`)** so the handlers keep their Rails-shaped contract: a
  handler's value is the whole body (String or a body object such as FragmentBody), the status is
  200 unless set, an unset Content-Type is `text/html;charset=utf-8`, 204/304/1xx carry no body or
  content headers, and Content-Length is counted for string bodies. Every request ends in
  `App#respond`, which also applies ActionDispatch's default Cache-Control and serves the public 404
  page when nothing matched. A new body drops a Content-Length set for an earlier one (except for
  HEAD and file bodies), which is what leaves FragmentBody pages chunked, as in the Sinatra app.
- **`halt`, `headers`, `status`, `etag`, `send_file` and the Accept parsing** are small methods in the
  app (Roda has no equivalents in core), matching what the shared handlers expect.
- **Data layer: Sequel.** Same API as the Sinatra app's DB (`rows`, `row`, `value`, `memo`,
  `memo_for`, `check_for_changes`, `generation`, `transaction { |w| w.run … }`). Underneath, every
  query is a Sequel prepared statement run by name through `Database#execute` (Rage's cd34c6b
  approach). Each DB is its own single-threaded Sequel database with a `:read_only` and a `:default`
  shard, so it holds exactly one reader and one writer connection, as the Sinatra app does:
  `PRAGMA data_version` only means something when it's read on the same connection each time.
  The writer's busy handler retries every 100 µs (Sinatra's 6da8ca4), and checkpoints are left to
  bin/checkpoint (auto-checkpoint off), as in Sinatra.
- **The app is frozen** after boot (`Campfire::App.freeze`), as Roda recommends; the process's
  Runtime is kept outside the class's own state for that reason.

## What's in, under the rule (Oct 7)

JP's rule: every optimization must be (1) a fix of our own bug or misconfiguration, (2) something the
Rust port does, cited in once-campfire-rust, or (3) a cache with Elixir precedent that JP approved
(read cache, kept sidebar, per-ETag messages page, room/search shell memo).

| Item | Category | Citation |
|---|---|---|
| Byte-offset page splitting | (1) bug in our shared code | char-index slicing was O(n) per fragment on UTF-8 pages |
| Random-token fragment markers | (1) security fix | audit finding: user text could forge markers |
| `config.ru` builds the Rack stack once | (1) bug | Sinatra a0cf295 |
| Production mode in the image | (1) misconfiguration | Sinatra ec1ccab |
| Falcon hosted without its ContentEncoding middleware | (1) misconfiguration | Compression already does Thruster's gzip; Falcon's only re-scanned headers |
| Compressed pieces: each fragment's deflate block and the text between | (2) Rust | crates/kit/src/deflater/splice.rs |
| Whole-body gzip kept by digest | (2) Rust | 2f755bf (`GZIPPED`, keyed by SHA-256) |
| Page ETags from page parts (message versions as a part) | (2) Rust | 2947c64, 2f755bf |
| Cookies only when they change | (2) Rust | 2947c64; README "Known differences" |
| `Sec-Fetch-Site` instead of CSRF tokens | (2) Rust | b567772 |
| Public-response cache (avatars, assets) | (2) Rust | crates/kit/src/front/cache.rs |
| Prepared statements, run by name | (2) Rust | crates/db/src/database.rs (`STATEMENT_CACHE_CAPACITY`) |
| WAL checkpoints in their own process (bin/checkpoint) | (2) Rust | crates/db/src/database.rs: checkpointer thread with its own connection |
| Read cache cleared on `PRAGMA data_version` | (3) approved | Elixir lib/campfire/db.ex (`cached`) |
| Kept sidebar until its data changes | (3) approved | Elixir lib/campfire/sidebar.ex |
| Messages page parts and gzip per ETag | (3) approved | Elixir lib/campfire/messages.ex |
| Room and search shell memoized by inputs | (3) approved | Elixir lib/campfire/room_page.ex, searches.ex |
| Remembered verified `session_token` signature | **flagged:** kept as Sinatra and Rage keep it after their pass | Elixir lib/campfire/auth.ex memoizes the session cookie; not on the approved list |

**Taken out under the rule** (they were in the Sinatra snapshot):

- The plain-text fast path (Sinatra ecf1b4d). Rust runs every body through its rich-text pipeline.
  Reverted in 48a788c.
- One Redis PUBLISH per post (Sinatra 410a6d5). Rust sends each member's unread ping as its own
  broadcast (crates/campfire/src/channels/broadcasts.rs, `unread_room`), so there's no batching
  precedent. Reverted in 48a788c.
- The 100 µs busy-handler retry (Sinatra 6da8ca4). Rust never retries the write lock: one writer
  thread with a queue (crates/db/src/database.rs). The writer now uses the sqlite3 gem's own
  `busy_handler_timeout=`, as Sinatra did before 6da8ca4 (697c2c5).

**Also taken out, mirroring the same pass on Sinatra and Rage** (Sinatra's commits, applied here so
the shared code stays identical; each is a Roda commit that names the Sinatra one):

- Records built from cached rows (Sinatra fa16398): built on every request again.
- The memo of message versions for page ETags (Sinatra 2e42e04): Rust computes ETag parts per
  request and keeps nothing derived from them.
- Building a new post's view from the request's own data (Sinatra 25e5b2e): the view and push
  payload are loaded again, as Rust's presenter does (crates/campfire/src/controllers/messages.rs,
  `broadcast_create`).
- Memoized Turbo stream names, signed blob ids and initials avatars (Sinatra bcf1a1e, 5267338,
  7a3e60d): signed or rendered on every request again.
- Remembered verified signatures now cover only the session_token cookie (Sinatra aefb3c5).

After this, every file outside `lib/campfire/app.rb` and `lib/campfire/db.rb` (the Roda and Sequel
layers) and the dev scripts is byte-identical to Sinatra's main.

## Verification (final image campfire-roda:v5, commit 44c135c)

- **Server HTML against the Rails reference** (script/compare over script/paths.txt, through the
  harness's normalizer): 64 pages identical on a fresh pass and on a cached pass, 128 of 128.
- **Write flows** (script/flows): 24 of 24 give the same status and redirect as the reference.
- **Fix checks** (tools/roda-fixcheck.sh, adapted from Rage's): 28 of 28 pass. They cover X-Request-Id,
  the /cable origin rules, forgery rules, bot-API forgery, marker injection, the sidebar's Link
  header, blob serving, boost length and private-IP bans.
- **Cache check mode** (CAMPFIRE_CHECK_CACHES=1, reads around posts and a rename from 4 processes):
  0 mismatches.
- **Harness cable and upload suites:** every message delivered at 100 and 1,000 clients.
- **Playwright parity, every seed:**

  | Seed | Cells passing |
  |---|---:|
  | default | 874 / 874 |
  | crowd | 25 / 25 |
  | custom_styles | 33 / 33 |
  | first_run | 16 / 16 |
  | restricted | 8 / 8 |

  No allowed differences. Results are in results/hetzner/roda/.

Before that, a local byte-for-byte diff against the Sinatra app (headers and bodies on 64 pages, with
and without a Turbo frame) matched except for `X-Cache` hit/miss, which depends on fetch order.

### Bugs found along the way, all fixed

- **Rack's MethodOverride and Files weren't required** (5701c2c). They were only loaded locally
  because Falcon pulled them in first. The container's boot step failed.
- **Bot API form bodies arrived empty** (590cb1b). Rack::MethodOverride reads a POSTed form to look for
  `_method`, and Falcon's input can't be read twice, so a bot's form-encoded message answered 422
  where Rails answers 201. The fix reads `rack.request.form_vars`. **The Sinatra app has the same
  bug:** it returns 422 for `curl --data 'hi' /rooms/:id/:bot_key/messages`, and the reference
  returns 201. It wasn't fixed there, because that's out of scope for this stream.
- **`send_file` didn't accept `disposition:`** (590cb1b): the disk-blob route answered 500.
- **A halt from the before-action was taken for an unmatched path** (cfdd3e4). A banned IP's POST
  got the 404 page instead of 429. Playwright's auth/sign_in/banned_ip state caught it.

## Results (Oct 8, image e1c9836 from 44c135c)

Five-app run, 3 runs in rotating order, with stock Rails, Sinatra (fb24b48), Rage (623fb2d) and Rust
(ccece30) in the same session; 0 errors. Requests/sec at 16 clients:

| | Rails | Sinatra | Rage | Roda | Rust |
|---|---:|---:|---:|---:|---:|
| Room | 222 | 11,303 | 10,146 | 12,431 | 21,206 |
| Messages | 362 | 16,197 | 24,784 | 19,386 | 23,634 |
| Sidebar | 467 | 22,533 | 33,989 | 27,366 | 20,652 |
| Search | 372 | 14,574 | 16,843 | 16,294 | 21,361 |
| Post | 197 | 1,851 | 1,639 | 1,732 | 4,122 |
| Avatar | 62,119 | 73,951 | 178,931 | 75,871 | 196,130 |

Cable at 1,000 clients for Roda: p50 delivery 7.9 ms, 104 msg/s saturated, every message delivered.
Upload 131 ms, idle anon 196 MB, cold start 1.4 s.

- **Mixed run** (room reads at 0 / 20 / 100 posts/s): 12,282 / 11,124 / 7,686. Post p50 at 100/s is
  3.2 ms.
- **Rust-level caching only** (`CAMPFIRE_CACHING=rust`): room 5,037, messages 8,413, sidebar 6,448,
  search 7,269, post 1,676.
- **Run 1's env.txt** has no Roda image ID: `campfire-roda:app` was tagged from v5 24 seconds into
  that run, before it reached Roda. All three runs used v5.

Raw results: results/hetzner/roda/ (roda-5app, roda-mixed, roda-rust-caching, the parity reports,
verify-v5.txt, compare-v5.txt).
