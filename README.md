# Campfire benchmarks: Rails, Sinatra and Rage

These are the notes, scripts and raw results for three Ruby takes on
[once-campfire](https://github.com/basecamp/once-campfire). Each one was measured with DHH's
harness from [once-campfire-rust](https://github.com/basecamp/once-campfire-rust) and checked
with its Playwright parity harness.

| Implementation | Code |
|---|---|
| Rails, optimized | [jpcamara/once-campfire, branch `perf`](https://github.com/jpcamara/once-campfire/tree/perf) |
| Sinatra + Falcon | [jpcamara/once-campfire-sinatra](https://github.com/jpcamara/once-campfire-sinatra) |
| Rage + Sequel | [jpcamara/once-campfire-rage](https://github.com/jpcamara/once-campfire-rage) |

## What's here

- `notes/what-made-them-fast.md`: start here. It lists every change, its measured effect, where
  the idea came from, and the caveats.
- `notes/audit.md`: an independent audit of the three implementations, covering divergences, cache
  correctness, security and benchmark method.
- `notes/{rails-opt,sinatra,rage}.md`: working notes for each implementation.
- `notes/elixir-rust-optimizations.md`: an analysis of the Rust port's history and the Elixir
  port's PR #5.
- `bench/`: the changed copy of the harness's `bench/run` (each change is marked `HETZNER CHANGE`),
  a probe script, and the PostgreSQL experiment.
- `tools/`: profiling, A/B and page-diff scripts. Set `BOX` / `BOX_IP` for your own machine.
- `results/hetzner/`: the raw result JSONs and parity reports.

## Status

This is a snapshot of work in progress. The open items, all described in `notes/`:

- **Security fixes in Sinatra and Rage are underway.** These come from the audit: stored XSS
  through uploads, no Origin check on `/cable`, a missing CSRF check on the bot API, and
  fragment-marker injection.
- **Whole-page response caching is being removed.** All three apps cached the finished room, search
  and messages pages. Neither the Rust nor the Elixir port does that, and it flatters a benchmark
  that never interleaves writes with reads. It's being replaced with Elixir-style assembly on every
  request.
- **The numbers here aren't final.** A final benchmark and a mixed read/write run come after those
  changes.
