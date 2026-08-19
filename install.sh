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
        local f="/tmp/ai-usage.bar.$UID"
        [ $(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) )) -gt 60 ] \
            && "$HOME/projects/ai-usage/ai-usage" --bar > "$f" 2>/dev/null
        local bar=$(<"$f") cols=$(tput cols 2>/dev/null || echo 80)
        [ -n "$bar" ] || return
        # Keep the status line compact even when a provider state is verbose.
        if [ "${#bar}" -ge "$cols" ]; then
            bar="${bar:0:$((cols>3?cols-3:0))}..."
        fi
        # Paint each provider as a colored badge. The width math above uses the
        # plain string; ANSI sequences are zero-width on screen.
        local disp
        disp=$(printf '%s' "$bar" | python3 -c "
import sys,re
s=sys.stdin.read()
palette = [(24,159),(130,255),(27,255),(236,255),(94,255)]
parts = s.split(' | ')
out=[]
for i,p in enumerate(parts):
    if not p: continue
    bg,fg=palette[min(i,len(palette)-1)]
    out.append(f'\033[48;5;{bg};38;5;{fg}m{p}\033[0m')
sys.stdout.write(' \033[38;5;244m│\033[0m '.join(out))
" 2>/dev/null)
        [ -n "$disp" ] || disp="$bar"
        # Draw on its own line; never save/restore or move to the right edge.
        printf '\r\033[2K%s\033[0m\n' "$disp"
    }
    PROMPT_COMMAND="_ai_bar${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi
EOF
  echo "==> bashrc wired"
fi

echo
echo "Done. Open a new shell or:  source ~/.bashrc"
echo "Test:                       $REPO/ai-usage --bar"
echo "Drop manual keys into:      ~/.config/ai-usage/<short>  (mode 600)"
echo "Auto-detect covers:         opencode / claude-code / codex / github-copilot"
