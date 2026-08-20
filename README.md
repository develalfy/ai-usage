# ai-usage — Persistent AI-subscription footer

A compact, colorized footer that lives in the tmux status line and is also
available on demand from any shell. tmux users see it at a glance; everyone
else can read it on demand with `ai-usage`.

```
[tmux status bar]  ◆ Claude 77% │ ⬢ OpenAI 39% │ ◆ MiniMax 5h 6% · week 43%
your-shell-prompt$
```

## Install

```bash
git clone git@github.com:develalfy/ai-usage.git ~/projects/ai-usage
~/projects/ai-usage/install.sh
```

The installer is idempotent: run it again after updating the checkout, or on
a fresh machine. It places two executables in `~/projects/ai-usage/`:

- `ai-usage` — the multi-line / compact provider fetcher
- `ai-usage-tmux-status` — a thin wrapper around `ai-usage --bar` with a
  private 60-second cache, designed to be the target of `~/.tmux.conf`

and appends a guarded block to `~/.tmux.conf` so the tmux status-right shows
the footer. If you were on the older Bash-`PROMPT_COMMAND` integration, the
installer removes that block from `~/.bashrc` automatically — no further
action needed.

Reload the tmux config without restarting your session:

```bash
tmux source-file ~/.tmux.conf
```

If you are not running tmux, skip that step: the `ai-usage` command is the
on-demand fallback (next section).

## What it shows

| Provider | Subscription data |
|---|---|
| Claude Code | Current 5-hour usage window (detailed view also shows 7-day usage) |
| Codex / ChatGPT | Current short rate-limit window (detailed view also shows the long window, reset time, plan, and spend control) |
| MiniMax Coding Plan | Current 5-hour and weekly quota usage |
| GitHub Copilot | Plan, when its installed credential format is supported |
| Agy / Antigravity | Shown as unavailable: no public usage endpoint exists |

Percentages are **used quota**, not quota remaining. Green is under 60%,
yellow is 60–84%, and red is 85% or higher.

## How the status line works

| Surface | Mechanism | Refresh |
|---|---|---|
| tmux status-right | tmux runs `ai-usage-tmux-status` | wrapper caches for 60 s, singleflight-locked so concurrent ticks share one fetch |
| Interactive terminal, no tmux | `ai-usage` | on demand, multi-line colored view |
| Anywhere | `ai-usage --bar` | on demand, one plain-text line per call |

The wrapper locates the sibling `ai-usage` via its own path, so it works
wherever the repo lands or however it is symlinked. The cache lives at
`${XDG_CACHE_HOME:-$HOME/.cache}/ai-usage-tmux/` (mode 700 directory,
mode 600 on the cached file). Force a refresh:

```bash
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/ai-usage-tmux/status"
```

## Credentials

Manual keys live in `~/.config/ai-usage/<provider>` and must be mode `600`. A
manual key overrides automatic detection.

| Provider | Automatic credential source |
|---|---|
| Claude | `~/.claude/.credentials.json` (Claude Code OAuth) |
| OpenAI | `~/.codex/auth.json` (Codex ChatGPT OAuth) |
| MiniMax | `~/.local/share/opencode/auth.json` or `~/.config/opencode/auth.json` (`minimax-coding-plan`) |
| Copilot | `~/.config/github-copilot/hosts.json` or `~/.config/gh/hosts.yml` |

MiniMax uses the International Token Plan endpoint (`api.minimax.io`). A
China-region key is not supported.

## Commands

```bash
ai-usage              # detailed, multi-line view in an interactive terminal
ai-usage --bar        # one plain-text line; consumed by the tmux footer (and reusable)
ai-usage-tmux-status  # tmux wrapper; rarely called directly
```

tmux is the persistent footer; the `--bar` invocation is the cache-agnostic
fallback for shell prompts, scripts, and one-off inspections. `ai-usage`
without flags prints a richer colored view (it does not write to the tmux
cache).

## Troubleshooting

- `unavailable` means credentials were found, but the provider's usage
  request failed or was rate-limited. It does not mean the subscription is
  inactive.
- `WARN: <file> is mode 644` means the manual key file is too permissive:
  run `chmod 600 <file>`.
- The tmux footer looks stale: the wrapper caches for 60 s by design; force
  a refresh with the cache-bust command under "How the status line works".
- The tmux footer never appears: run `tmux source-file ~/.tmux.conf` to pick
  up the installer's changes, and confirm `~/.tmux.conf` contains the
  `ai-usage-tmux-status` marker comment. Outside tmux, use `ai-usage`
  directly.
- Run `ai-usage` directly for the detailed view and `bash -n ai-usage` to
  check script syntax.

## Keeping documentation current

Every provider, output, credential-source, or installer change should update
this README in the same change.
