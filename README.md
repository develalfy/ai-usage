# ai-usage — terminal usage bar for AI subscriptions.

One line, right side of your bash prompt, showing usage/credits for each AI
subscription. Auto-detects keys from installed agent CLIs, or reads manual
keys from `~/.config/ai-usage/<short>`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/develalfy/ai-usage/main/install.sh | bash
```

Or with SSH:

```bash
git clone git@github.com:develalfy/ai-usage.git ~/projects/ai-usage && ~/projects/ai-usage/install.sh
```

Then `source ~/.bashrc` (or open a new shell). The bar appears on the right
side of your prompt, updating once a minute.

**Update later:** just re-run the same command — idempotent.

## Wire it (bash)

```bash
# in ~/.bashrc
if [ -x "$HOME/projects/ai-usage/ai-usage" ]; then
    _ai_bar() {
        local f=/tmp/ai-usage.bar
        [ $(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) )) -gt 60 ] \
            && "$HOME/projects/ai-usage/ai-usage" --bar > "$f" 2>/dev/null
        local bar=$(<"$f")
        [ -n "$bar" ] && printf '\e7\e[%dG\e[36m%s\e[0m\e8' $(( $(tput cols) - ${#bar} )) "$bar"
    }
    PROMPT_COMMAND="_ai_bar;$PROMPT_COMMAND"
fi
```

## Key resolution (per provider, in order)

1. **Manual** — `~/.config/ai-usage/<short>` (mode 600, wins over auto)
2. **Auto-detect** — known auth files of installed agent CLIs:

   | Provider  | Detected from                                                     |
   |-----------|-------------------------------------------------------------------|
   | openrouter| `~/.local/share/opencode/auth.json`, `~/.config/openrouter/...`    |
   | anthropic | `~/.claude.json` (oauth), `~/.config/anthropic/auth.json`         |
   | openai    | `~/.config/openai/auth.json`, `~/.codex/auth.json`                |
   | copilot   | `~/.config/github-copilot/hosts.json`, `~/.config/gh/hosts.yml`   |
   | agy       | manual only — no known agent CLI auth file yet                     |

## Providers

| short      | name       | endpoint                                                  |
|------------|------------|-----------------------------------------------------------|
| openrouter | OpenRouter | `https://openrouter.ai/api/v1/auth/key`                  |
| anthropic  | Claude     | `https://api.anthropic.com/v1/organizations/me`          |
| openai     | OpenAI     | `https://api.openai.com/v1/dashboard/billing/credit_grants` |
| copilot    | GitHub     | `https://api.github.com/copilot_internal/user`            |
| agy        | Agy        | `https://api.agy.ai/v1/me`                                |

## Why both modes

If you use Claude Code / opencode / GitHub Copilot / openai CLI regularly, their
auth is already on disk. The bar lights up automatically — no extra setup.
If you only pay for a subscription but never install the CLI (e.g. Agy today),
drop your API key into `~/.config/ai-usage/agy` and you're done.

## Debugging

- `ai-usage` (no flag) → verbose print, shows `[auto]` vs `[file]` source
- `ai-usage --bar` → silent bar mode, for status-line consumers
- `WARN: <file> is mode 644` → too-permissive key file, `chmod 600 <file>`

ponytail: hardcoded endpoint list — extend when adding a provider.