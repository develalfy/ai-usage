# task — ai-usage 2h evolution (Phase 0 plan)

## Goal
Turn `~/projects/ai-usage/` into a polished, working prompt-bar that the user
will actually use. Fix what doesn't work today, harden what does, add a couple
of useful features without over-building.

## Acceptance criteria
1. **Bar shows real numbers, not `?`** for at least OpenRouter (auto-detected).
2. **`ai-usage --bar` exits 0** in <2s even when every provider fails.
3. **Idempotent install** — re-running `install.sh` doesn't double-wire bashrc,
   doesn't leave stale entries, always leaves the file executable.
4. **Self-test passes**: a `test.sh` that exercises every code path with
   mocked responses (file-mode key, auto-detect, JSON extract, perms warning,
   no-key path, --json, --check, --help).
5. **One new feature chosen from the list below** — ship the lazy version.

## Today's bugs (root cause, not symptoms)
- OpenRouter extraction path `data,0,usage` is wrong: live API returns
  `data.usage_monthly` (USD cumulative). Fix the path. Format with `$` so
  the user reads it correctly.
- Anthropic extraction path `id` returns an org id — not a quota number.
- OpenAI dashboard endpoint needs a Session cookie, not an API key.
- `install.sh` writes a bashrc block via heredoc with no guard for partial
  writes. Idempotency fix: write to tmp, mv, only then append to bashrc.

## Provider plan (after fixes)
- **openrouter** — show direct + byok monthly spend from `data.usage_monthly` + `data.byok_usage_monthly`
- **anthropic** — show `org id` short form
- **openai** — show total_granted from credit_grants (may 401 if key lacks dashboard)
- **copilot** — copilot_plan from /copilot_internal/user
- **minimax** — MiniMax Coding Plan, separate dispatcher in script
- **agy** — keep stub (no public endpoint)

## New features (one chosen)
- `--json` mode for piping into scripts/dashboards
- `--check` mode for cron (exit 1 if any provider errored)
- `--help` mode

## Skipped (per Ponytail rules)
- Provider plugin system (case statement is simpler)
- HTTP caching beyond the 60s bar file
- TUI dashboard
- Notifications (no event loop here)

## Phases
- [x] Phase 0: read source + live-probe providers
- [x] Phase 1: fix extraction paths + Bearer prefix detection
- [x] Phase 2: harden install.sh (atomic, idempotent)
- [x] Phase 3: add selftest with mocked HTTP (18/18)
- [x] Phase 4: ship --json, --check, --help
- [x] Phase 5: dogfood — confirmed live bar shows real numbers
- [x] Phase 6: commit, push, DONE.md, README updates

STATUS: COMPLETE
