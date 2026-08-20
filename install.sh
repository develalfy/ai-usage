#!/usr/bin/env bash
# ai-usage installer — clones repo to ~/projects/ai-usage, wires tmux status-right.
# Idempotent. Run again to update to latest.
# ponytail: apt-installs nothing; owns only ~/.tmux.conf (and the legacy
# ~/.bashrc block from the earlier PROMPT_COMMAND hook). Never touches
# unrelated user content.

set -euo pipefail
REPO="$HOME/projects/ai-usage"
REMOTE="git@github.com:develalfy/ai-usage.git"
WRAPPER="$REPO/ai-usage-tmux-status"

if [ -d "$REPO/.git" ]; then
  echo "==> updating existing install"
  git -C "$REPO" pull --ff-only
elif [ -d "$REPO" ] && [ -x "$REPO/ai-usage" ] && [ -x "$WRAPPER" ]; then
  # ponytail: a local-copy checkout (no .git) — skip remote ops, just re-wire.
  # Useful for dev / test and harmless for real installs that already have one.
  echo "==> reusing existing checkout at $REPO (no .git)"
else
  echo "==> cloning $REMOTE"
  mkdir -p "$(dirname "$REPO")"
  git clone "$REMOTE" "$REPO"
fi

chmod +x "$REPO/ai-usage" "$WRAPPER"

# --- migrate: drop the legacy PROMPT_COMMAND block from ~/.bashrc ----
# The older installer hooked Bash's prompt to draw a status line. The tmux
# footer replaces it — remove the block so the two don't compete.
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ] && grep -qF '# ai-usage-bar —' "$BASHRC"; then
  echo "==> removing legacy ai-usage-bar block from ~/.bashrc"
  # Delete from the legacy marker comment (unique to that block) through the
  # outer closing `fi` at column 0. Inner `if ... fi` and the function's `}`
  # are indented, so `^fi$` matches only the outer one.
  sed '/^# ai-usage-bar — terminal usage bar for AI subscriptions$/,/^fi$/d' \
    "$BASHRC" > "$BASHRC.tmp"
  mv "$BASHRC.tmp" "$BASHRC"
fi

# --- wire ~/.tmux.conf (guarded, idempotent) ------------------------
TMUXCONF="$HOME/.tmux.conf"
TMUX_MARK="ai-usage-tmux-status"
if [ -f "$TMUXCONF" ] && grep -qF "$TMUX_MARK" "$TMUXCONF"; then
  echo "==> tmux.conf already wired ($TMUX_MARK)"
elif [ -f "$TMUXCONF" ]; then
  echo "==> wiring tmux.conf with ai-usage status-right"
  cat >> "$TMUXCONF" <<EOF

# $TMUX_MARK — persistent AI subscription footer (added by install.sh)
set -g status-position bottom
set -g status-interval 15
set -g status-right-length 120
set -g status-right '#[fg=colour250,bg=colour236]  AI #[fg=colour117]#($WRAPPER) #[default]'
EOF
else
  echo "==> creating ~/.tmux.conf with ai-usage status-right"
  cat > "$TMUXCONF" <<EOF
# $TMUX_MARK — persistent AI subscription footer (added by install.sh)
set -g status-position bottom
set -g status-interval 15
set -g status-right-length 120
set -g status-right '#[fg=colour250,bg=colour236]  AI #[fg=colour117]#($WRAPPER) #[default]'
EOF
fi

echo
echo "Done."
echo "  test:        $REPO/ai-usage --bar"
echo "  tmux reload: tmux source-file ~/.tmux.conf   (or open a new tmux session)"
echo "  manual key:  ~/.config/ai-usage/<short>  (mode 600)"
echo "  auto-detect: opencode / claude-code / codex / github-copilot"
