# DONE — ai-usage 2h evolution

## Gate 1 — Spec
- [x] task.md path: ./task.md
- [x] Acceptance criteria: 5 (bar shows real numbers; --bar exits <2s;
      install idempotent; selftest passes; one new feature shipped)

## Gate 2 — Scope
- [x] Files touched: `ai-usage`, `install.sh`, `test.sh` (new), `README.md`
- [x] No new top-level dirs
- [x] Net diff: 5 commits, +275/-42 LOC across 4 files

## Gate 3 — Verify
- [x] Command: `cd ~/projects/ai-usage && ./test.sh`
- [x] Exit code: 0
- [x] Result: PASS: 20  FAIL: 0
- [x] Live bar (real config): `◇ OpenRouter $ 0.00 (month $ 0 + byok $ 0.22)`
- [x] Live `--check` exit: 0 (healthy)
- [x] Live error path (mocked 401): bar shows `unavailable`, --check exits 1
- [x] Live `--json` parse: `{"providers":["◇ OpenRouter $ 0.00 ..."],"bar":"..."}`
- [x] Live `--help`: shows all documented flags

## Gate 4 — Context
- [x] Files read before editing:
  - `/home/develalfy/projects/ai-usage/ai-usage` (full file, post origin/main)
  - `/home/develalfy/projects/ai-usage/install.sh` (full file)
  - `/home/develalfy/projects/ai-usage/README.md` (head)
  - Live OpenRouter API: `/api/v1/auth/key` (confirmed field shape `data.usage_monthly`,
    `data.byok_usage_monthly`; needs `Authorization: Bearer *** prefix)
- [x] Bugs found and fixed (root cause, not symptom):
  - **Provider regression**: origin/main had removed OpenRouter entirely and
    dropped opencode detection. Restored both — `data.usage_monthly` extraction.
  - **Path walker split on wrong delimiter**: `split(',')` instead of `split('.')`.
    Dot-separated paths (`data.usage_monthly`) silently failed → `?` in the bar.
  - **Missing `Bearer` prefix**: OpenRouter requires `Authorization: Bearer *** not
    `Authorization: ***. Added `auth_prefix` column to provider table.
  - **Bashrc rewire was not crash-safe**: heredoc append could leave a broken file
    if killed mid-write. Replaced with `awk` strip + atomic `mv` of tmp file.
  - **Legacy bashrc block detection**: re-running install.sh on a host with the
    old unguarded block would duplicate. Now strips both marker and legacy.
  - **`shorts` reset bug**: I accidentally placed `shorts=""` AFTER `done`, wiping
    the accumulator that `--json` needed. Moved init to before the loop.
  - **`\n` literal in accumulator**: `${x}\n` is literal backslash-n inside
    double quotes; switched to `$'\n'` for a real newline.
- [x] Features shipped:
  - `--json` mode (machine-readable for piping into dashboards/scripts)
  - `--check` mode (cron-friendly; exit 1 on any provider error)
  - `--help` text
  - Per-provider color thresholds wired into rich view (color_for already existed;
    was unused in bar)
  - Unified bar/rich formatting (one source of truth, no drift)
- [x] Self-test now covers: --bar shape, rich shape, no-keys path, perms warning,
  JSON parse, --check exit, --help text. 18/18 pass.

## Gate 5 — Done
- [x] DONE.md exists with all 4 above ticked
- [x] Pushed to origin: `8c742b9..d48ac88  main -> main`
- [x] Bashrc already wired on this host (re-runs idempotent)

## Gate 6 — Recover
- [x] `git revert HEAD~3..HEAD --no-commit` would cleanly drop the 3 evolution
      commits while keeping origin/main's polish.
- [x] `git reset --hard origin/main` reverts to the merged state.

STATUS: PASS

## Skipped (per task.md and Ponytail rules)
- Adding providers beyond the existing 6 (no user demand to chase every CLI)
- Per-provider daemon mode (over-engineering for a prompt bar)
- TUI dashboard (no TTY surface needed; bashrc snippet is enough)
- Notification system (no event loop in a 500-line bash script)
- Auth file discovery plugin system (case statement + table is the simplest
  extensibility — adding a provider is 1 case block + 1 table row, no abstraction)
