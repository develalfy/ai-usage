# DONE — ai-usage 2h evolution

## Gate 1 — Spec
- [x] task.md path: ./task.md
- [x] Acceptance criteria: bar shows real numbers; --bar exits <2s;
      install idempotent; selftest passes; multiple new features shipped.

## Gate 2 — Scope
- [x] Files touched: `ai-usage`, `install.sh`, `test.sh` (new), `README.md`,
      `DONE.md`, `task.md`, `.github/workflows/selftest.yml`
- [x] No new top-level dirs
- [x] Net diff: 30 commits this session, all pushed to origin/main

## Gate 3 — Verify
- [x] Command: `cd ~/projects/ai-usage && ./test.sh`
- [x] Exit code: 0
- [x] Result: **PASS: 29  FAIL: 0**
- [x] Live bar (real config): `◇ OpenRouter $ 0.00 (month $ 0 + byok $ 0.29)`
- [x] Live bar contains real ANSI ESC bytes (terminal renders green)
- [x] Live `--check` exit: 0 (healthy)
- [x] Live `--json` parse: dict with `providers[]` + `bar` (with ANSI)
- [x] Live `--help`: all documented flags listed
- [x] Live prompt hook: writes per-PID cache `/tmp/ai-usage.bar.$$` with
      real ESC bytes; positions at right edge with correct visible length

## Gate 4 — Context
- [x] Files read before editing (cumulative):
  - `ai-usage` (multiple times, 600+ lines)
  - `install.sh`
  - `test.sh`
  - `README.md`
  - `DONE.md` / `task.md`
- [x] Live OpenRouter API: confirmed `/api/v1/auth/key` returns `data.usage_monthly`
      and `data.byok_usage_monthly`; needs `Authorization: Bearer *** prefix.
- [x] Bash quirk verified: bash double-quoted strings do NOT interpret `\033`
      (stays as 4 literal chars), but `$'\033'` does. Bar text stored as literal
      `\033` (4 chars) and emitted with `printf '%b'` to produce real ESC bytes.

## Bugs fixed (this session, root cause)
1. **OpenRouter provider regressed**: origin/main removed it entirely and dropped
   opencode auth detection. Restored both.
2. **Path walker split on `,` instead of `.`**: dot-separated paths (`data.foo.bar`)
   silently failed → `?` in bar.
3. **Missing `Bearer` prefix**: OpenRouter needs `Authorization: Bearer *** not
   `Authorization: *** Added `auth_prefix` column.
4. **Bashrc install not crash-safe**: heredoc could leave broken file. Replaced
   with `awk` strip + atomic `mv`.
5. **Legacy bashrc block**: re-running install on a host with the old block
   duplicated. Now strips both marker and legacy.
6. **`shorts=""` reset bug**: reset was AFTER `done`, wiping the accumulator
   needed by `--json`. Moved to before the loop.
7. **`\n` literal in accumulator**: switched to `$'\n'`.
8. **OAuth branches (Claude / Codex) skipped color formatting**: bar text was
   plain while other providers had per-segment ANSI. Now consistent.
9. **minimax branch skipped color**: same fix.
10. **Manual key file with whitespace promoted to credential**: raw file content
    went into the `Authorization` header → API returned empty → `?` in bar.
    Now rejects keys with whitespace, suggests the right format.
11. **Manual key file with JSON blob promoted to credential**: user pasted
    `~/.claude.json` by accident → entire JSON blob became the key. Now extracts
    a string field if the file looks like JSON.
12. **Critical: ANSI colors silently broken** — `bar` variable stored the literal
    4-char `\033` (bash double-quotes don't interpret it), but the script
    emitted with `printf '%s'`, sending the 4 chars to the terminal instead of
    the ESC byte. Terminal rendered `\033[1;32m` as visible text. Changed all
    output points to `printf '%b'` so the literal `\033` becomes a real ESC byte.
13. **Off-screen bar**: bashrc hook used `${#bar}` for right-edge positioning,
    which counted ANSI bytes → bar was 19 chars off-screen on a 52-byte bar.
    Now strips ANSI via `sed` to compute visible length.
14. **Bash escaping `\t` inside `python3 -c "..."`**: bash ate the backslash,
    leaving python with bare `t` identifier → `NameError`. Switched to `chr(9)`.
15. **API-error over-trigger**: `'"error"' in raw[:200]` matched any JSON
    response that contained the substring `"error"` (which is every response
    with a key named `error`). Now checks `raw.lstrip().startswith('{"error"')`.
16. **`--check` didn't honor NO_COLOR**: cron output had ANSI bytes that broke
    downstream parsers. Now strips when `$NO_COLOR` is set.
17. **`local` inside `case`**: bash error "local: can only be used in a function".
    Removed `local` declarations from inside `case` blocks.

## Features shipped
- `--json` mode (machine-readable)
- `--check` mode (cron/alerting; prints which providers errored)
- `--help` + `--version`
- `--no-color` flag + `$NO_COLOR` env (https://no-color.org/)
- Per-segment ANSI color thresholds in `--bar` (green/yellow/red)
- Per-segment ANSI colors in rich view (Claude, OpenAI, Codex OAuth branches)
- Per-segment ANSI colors in minimax branch
- Per-PID cache file (no multi-shell write race)
- Bashrc prompt hook with correct ANSI stripping for visible-length positioning
- Manual key validation (whitespace rejection + JSON blob extraction)
- `~/.config/ai-usage/<short>` manual key support
- Auto-detect from opencode, claude-code, codex
- GitHub Actions CI workflow
- Self-test covers 29 cases: bar shape, rich shape, no-keys, perms warn,
  color codes (green + gray separator), OAuth color, malformed keys,
  JSON-key extraction, NO_COLOR, --no-color, --version, --help, error path

## Skipped (per Ponytail)
- Adding providers beyond the existing 6 (no user demand to chase every CLI)
- Per-provider daemon mode (over-engineering for a prompt bar)
- TUI dashboard
- Notification system
- Auth file discovery plugin system (case statement + table is the simplest)

STATUS: PASS — 30 commits, 29/29 tests, real ESC bytes on the wire.
