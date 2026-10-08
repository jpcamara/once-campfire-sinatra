# Precedent audit

JP's rule: "if they're not things done in rust, I think not." Every performance change in the three
Ruby apps has to be one of these:

- **Bug fix**: a fix of our own bug or misconfiguration.
- **Rust**: something the Rust port does, cited to its code or commits (`once-campfire-rust` at
  ccece30).
- **Elixir cache**: one of the caches the Elixir port has, which JP approved earlier. These are the
  `data_version` read cache, the kept sidebar, the per-ETag messages page, the room/search shell memo,
  the verified session_token memo (`lib/campfire/auth.ex`) and the avatar-token memo
  (`lib/campfire/mentions.ex`).

Anything else is reverted. Grey cases are decided by the strict reading: the Rust or Elixir code has to
do the same thing, not just get a similar result.

The deciding facts from the Rust source:

- **Writes:** one writer thread takes a queue of writes and never retries a lock. WAL checkpoints run on
  their own thread (`crates/db/src/database.rs`).
- **Message bodies:** every body goes through `Content::load` / `to_html` (`canonical_body`,
  `crates/campfire/src/controllers/messages.rs`), with no plain-text shortcut.
- **New messages:** a new message's row isn't read back (`create_message`), but `broadcast_create` builds
  its view through the presenter, which reads the creator and rich text. The response reuses the
  fragment the broadcast just rendered.
- **Broadcasts:** a post's broadcasts go out one by one (`message_create` and `unread_room`,
  `crates/campfire/src/channels/broadcasts.rs`).
- **Push:** the badge is counted per subscription (`PushSubscription::badge`). Nothing is queried when
  nobody is mentioned (`for_mentioned_users`). No user is loaded per subscription.
- **No memos:** stream names, signed blob ids, avatar tokens and initials SVGs are generated on each use.
  No memoized message-version list feeds the ETag. No records are built from cached rows.

## Sinatra

| Commit | Change | Class | Evidence |
|---|---|---|---|
| c091b1e | gzip from cached blocks for runs of message fragments | Rust | abcaa09 "Splice precompressed messages into gzipped pages" |
| f84eb13 | static files from memory with cached gzip | Rust | e78bce9, `crates/assets/src/serve.rs` (embedded public/) |
| f84eb13 | initials avatar SVG cache | none → reverted (7a3e60d) | Rust renders initials per request (`render_initials`, `users/avatars.rs`) |
| a6e0111 | bounded per-process fragment cache | Rust | `crates/views/src/fragment_cache.rs`, 1d6ac20 |
| b37214d | one Redis subscription per process | Bug fix | subscriptions leaked and messages dropped; Rust has one in-process pub/sub |
| e3f5ecc | split pages by byte offset | Bug fix | character slicing was O(n) per slice on UTF-8 |
| 32039ac | keep each page segment's deflate block | Rust | 2947c64 "Cache every part of a page" |
| 98021cd | keep a body's gzip by its digest | Rust | 2f755bf (`GZIPPED`, `crates/kit/src/deflater.rs`) |
| 8f1a529 | build a new message's view and push payload from the request's data | none → reverted (25e5b2e) | Rust reads the view's data through the presenter and the body for the push payload |
| 2c86dd0 | read cache cleared on `PRAGMA data_version` | Elixir cache | `DB.cached`, `lib/campfire/db.ex` |
| b249617 | keep the finished sidebar | Elixir cache | `lib/campfire/sidebar.ex` |
| a0cf295 | build the Rack stack once | Bug fix | `config.ru` rebuilt it per request |
| ec1ccab | run in production | Bug fix | the image ran in development |
| e74054a | Falcon without its ContentEncoding middleware | Bug fix (config) | two compression layers; Rust compresses in one place (`crates/kit/src/deflater.rs`) |
| 345b5f1 | keep records built from cached rows | none → reverted (fa16398) | Elixir keeps rows, not records; Rust has no read cache |
| 69a39e0 | remember verified signatures, every verifier | narrowed to session_token (aefb3c5) | Elixir keeps only the session_token cookie (`session_token/1`, `lib/campfire/auth.ex`) |
| 07a07a3 | Thruster-style cache for public responses | Rust | `crates/kit/src/front/cache.rs` |
| 82050e6, 3591f56, 1dd8a67 | WAL checkpoints off the request path | Rust | checkpointer thread, `crates/db/src/database.rs` |
| ecf1b4d | plain-text bodies skip the rich-text pipeline | none → reverted (25ececc) | `canonical_body` always parses |
| 410a6d5 | a post's broadcasts in one PUBLISH | none → reverted (ba20615) | Rust broadcasts one by one |
| 6da8ca4 | busy write lock retried every 100 µs | none → reverted (e583564) | Rust has one writer thread and never retries |
| 2d97a37 | `/assets` and `/cable` by prefix; one before filter | Rust | public files before routing, `/cable` before the route table (`crates/campfire/src/app.rs` lines 7–10, 192) |
| b99c0c9 | message versions part of page ETags | Rust (ETag from parts), memo reverted (2e42e04) | Rust computes ETag parts per request and keeps no list |
| bbddf04 | room/search assembled per request; per-ETag messages page | Elixir cache | `room_page.ex`, `searches.ex`, `messages.ex` |
| (app.rb) | memoized avatar tokens | Elixir cache | `lib/campfire/mentions.ex` memo `{:avatar_token, id}` |
| (rails_compat.rb) | memoized signed stream names | none → reverted (bcf1a1e) | Rust signs per render (`rails_compat::turbo::signed_stream_name`) |
| (storage.rb) | memoized signed blob ids | none → reverted (5267338) | Rust signs per render |
| 41e2238 | YJIT on | JP's rule | |

## Rage

| Commit | Change | Class | Evidence |
|---|---|---|---|
| cd34c6b | named prepared statements | Rust | `STATEMENT_CACHE_CAPACITY`, `crates/db/src/database.rs`; `execute_cached`/`query_row_cached` throughout |
| fd721e0, 4cf101b, 93ea6b1 | bind limits, binary binds, file reads outside the scheduler | Bug fix | wrong results and stalls |
| 7734116 | split pages by byte offset | Bug fix | as Sinatra |
| c83ab7b | keep each page segment's gzip | Rust | 2947c64 |
| a98f212 | keep a body's gzip by its digest | Rust | 2f755bf |
| 807a8e1 | read cache | Elixir cache | `lib/campfire/db.ex` |
| 34bd5c8 | kept sidebar | Elixir cache | `lib/campfire/sidebar.ex` |
| 39dbd64 | messages page kept per ETag | Elixir cache | `lib/campfire/messages.ex` |
| f5ec624 | room/search shell memo, per-request assembly | Elixir cache | `room_page.ex`, `searches.ex` |
| 251d43f | build a new message's view and push payload from the request's data | none → reverted (0a35d02), keeping its "writes' responses aren't kept compressed" | as Sinatra 8f1a529 |
| 3ce184c | Thruster-style public cache | Rust | `crates/kit/src/front/cache.rs` |
| (runtime.rb) | memoized avatar tokens | Elixir cache | `mentions.ex` |
| (rails_compat.rb, storage.rb, support.rb) | memoized stream names, signed blob ids, initials SVGs | none → reverted (c2a87bc, f8538d2, b533866) | Rust generates each per use |

## Rails (optimized)

| Commit | Change | Class | Evidence |
|---|---|---|---|
| decb1c6 | Falcon; no `Rack::Deflater`; Redis `compress: false`; no `Rack::ETag`; 4 workers | Bug fix (config) | Thruster already gzips, so stock compresses twice. Rust keeps fragments uncompressed in memory. Falcon was JP's call. `Rack::Deflater` and `Rack::ETag` came back later for parity. |
| 8cf1a6b | no `public/` disk probes for other paths | Rust | public files from an embedded index, no disk per request (`crates/assets/src/serve.rs`, `app.rs` 192) |
| 49b11e2 | stylesheet and importmap tags once per process | Rust | b93306d "Render the layout's stylesheet link tags once per process" |
| 104bd48 | `Current.account` once per request | Rust | `Layout::load` reads the account once per page (`presenters/view_context.rs`) |
| d4b7c9e | fragment cache entries in process | Rust | `crates/views/src/fragment_cache.rs` (in-process, byte-bounded) |
| 34216d3 | cache versions without a connection checkout | Rust | `cache_key_with_version` is a pure function of the row (`fragment_cache.rs` line 339) |
| ca2309a | quick boost forms without `form_with` | Rust | the forms are literal template HTML (`crates/views/templates/messages/_actions.html` line 12) |
| e70715f | `Sec-Fetch-Site` instead of CSRF tokens | Rust | b567772 |
| 7b53b22 | rewindable request bodies under Falcon | Bug fix | the bot API returned 422 |
| d61f218, 544b4bb | keep each page's gzip by digest | Rust | 2f755bf |
| 7b4b92e, f6e0000 | read cache | Elixir cache | `db.ex` |
| 1e2ac5b, 115de7b | kept sidebar | Elixir cache | `sidebar.ex` |
| 025b8be | messages page per ETag | Elixir cache | `messages.ex` |
| afa98e6 | cookies only when they change | Rust | 2947c64 |
| abe0675 | push: preload users; skip the empty-mentions query | Rust | no user read per subscription; `for_mentioned_users` returns early |
| abe0675 | push: one badge count per user | none → reverted (0687ce8) | `PushSubscription::badge` counts per subscription |

## Not counted as optimizations

These are parity, security or correctness changes, not speed work:

- the audit fixes
- headers
- HTTPS mode
- `X-Request-Id`
- the browser-check order
- `Rack::Deflater` restored

The `CAMPFIRE_CACHING=rust` switch remains. It now turns off only Elixir caches.
