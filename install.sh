#!/usr/bin/env bash
# ai-usage installer — clones repo to ~/projects/ai-usage, wires bash PROMPT_COMMAND.
# Idempotent. Run again to update to latest.
# ponytail: apt-installs nothing, edits only ~/.bashrc with a guarded block.

set -euo pipefail
REPO="$HOME/projects/ai-usage"
REMOTE="git@github.com:develalfy/ai-usage.git"

if [ -d "$REPO/.git" ]; then
  echo "==> updating existing install"
  git -C "$REPO" pull --ff-only
else
  echo "==> cloning $REMOTE"
  mkdir -p "$(dirname "$REPO")"
  git clone "$REMOTE" "$REPO"
fi

chmod +x "$REPO/ai-usage"

# Wire bashrc — guarded block we can re-run safely.
MARK="ai-usage-bar"
if grep -qF "$MARK" ~/.bashrc 2>/dev/null; then
  echo "==> bashrc already wired"
else
  cat >> ~/.bashrc <<'EOF'

# ai-usage-bar — terminal usage bar for AI subscriptions
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
EOF
  echo "==> bashrc wired"
fi

echo
echo "Done. Open a new shell or:  source ~/.bashrc"
echo "Test:                       $REPO/ai-usage --bar"
echo "Drop manual keys into:      ~/.config/ai-usage/<short>  (mode 600)"
echo "Auto-detect covers:         opencode / claude-code / codex / github-copilot"