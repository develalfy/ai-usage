# ai-usage — terminal usage bar for AI subscriptions

A compact, colorized status line in your Bash prompt. It refreshes once a minute and never shares the line where you type commands.

```
◇ OpenRouter $ 0.00 (month $ 0 + byok $ 0.22) │ ◆ Claude org-12345 │ ⬢ OpenAI 100.00 │  GitHub business
you@host:~$
```

## Flags

| Flag       | What                                                              |
|------------|-------------------------------------------------------------------|
| (none)     | Interactive view with colors, badges, and per-provider status     |
| `--bar`    | Compact single line — what the prompt status line uses            |
| `--json`   | Machine-readable: `{providers:[...], bar:"..."}`                   |
| `--check`  | Print bar; exit 1 if any provider reported an error (for cron)     |
| `--help`   | Show usage                                                        |

## Install

```bash
git clone git@github.com:develalfy/ai-usage.git ~/projects/ai-usage
~/projects/ai-usage/install.sh
source ~/.bashrc
```

The installer is idempotent: run it again after updating the checkout.

## Test

The repo ships a self-test that mocks HTTP and exercises every code path
(file-mode key, auto-detect, JSON extract, perms warning, no-key path,
`--json`, `--check`, `--help`). 18 assertions, all pass.

```bash
cd ~/projects/ai-usage && ./test.sh
```

CI runs this on every push via `.github/workflows/selftest.yml`.

## What it shows

| Provider | Subscription data |
|---|---|
| OpenRouter | Current monthly spend (direct + byok to upstream providers), with ANSI color threshold |
| Claude Code | Current 5-hour + 7-day usage windows (Claude Code OAuth), with ANSI color threshold |
| Codex / ChatGPT | Current short rate-limit window (Codex ChatGPT OAuth), with ANSI color threshold |
| MiniMax Coding Plan | Current 5-hour and weekly quota usage, with ANSI color threshold |
| GitHub Copilot | Plan (when credential format is supported) |
| Agy / Antigravity | Shown as unavailable: no public usage endpoint exists |

Percentages are **used quota**, not quota remaining. Green is under 60%, yellow is 60–84%, and red is 85% or higher.

## Credentials

Manual keys live in `~/.config/ai-usage/<provider>` and must be mode `600`. A manual key overrides automatic detection.

| Provider | Automatic credential source |
|---|---|
| Claude | `~/.claude/.credentials.json` (Claude Code OAuth) |
| OpenAI | `~/.codex/auth.json` (Codex ChatGPT OAuth) |
| MiniMax | `~/.local/share/opencode/auth.json` or `~/.config/opencode/auth.json` (`minimax-coding-plan`) |
| Copilot | `~/.config/github-copilot/hosts.json` or `~/.config/gh/hosts.yml` |

MiniMax uses the International Token Plan endpoint (`api.minimax.io`). A China-region key is not supported.

## Commands

```bash
ai-usage            # detailed, multi-line view in an interactive terminal
ai-usage --bar      # compact line used by the Bash prompt integration (ANSI-colored)
ai-usage --no-color # same as --bar but with ANSI codes stripped (also honors $NO_COLOR)
ai-usage --json     # {providers:[...], bar:"..."} for piping into scripts
ai-usage --check    # print bar; exit 1 if any provider errored (cron/alerting)
ai-usage --version  # print version and exit
```

The `--bar` form embeds per-segment ANSI colors (green/yellow/red based on
the provider's utilization) so the prompt line lights up at a glance when
something is in trouble. The Bash prompt integration places `--bar` on the
right edge of the terminal without taking the typing line.

The prompt integration caches the compact status line at `/tmp/ai-usage.bar.$UID` for 60 seconds. Force a refresh:

```bash
rm -f "/tmp/ai-usage.bar.$UID"
source ~/.bashrc
```

## Troubleshooting

- `unavailable` means credentials were found, but the provider's usage request failed or was rate-limited. It does not mean the subscription is inactive.
- `WARN: <file> is mode 644` means the manual key file is too permissive: run `chmod 600 <file>`.
- Run `ai-usage` directly for the detailed view and `bash -n ai-usage` to check script syntax.

## Keeping documentation current

Every provider, output, credential-source, or installer change should update this README in the same change.
