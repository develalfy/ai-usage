#!/usr/bin/env bash
# ai-usage installer — clones repo to ~/projects/ai-usage, wires bash PROMPT_COMMAND.
# Idempotent. Re-run any time to update.
# ponytail: edits only ~/.bashrc (guarded block). No system packages.

set -euo pipefail
REPO="$HOME/projects/ai-usage"
REMOTE="${AI_USAGE_REPO:-git@github.com:develalfy/ai-usage.git}"
MARK="ai-usage-bar"
BASHRC="$HOME/.bashrc"

# ----- Step 1: always clean bashrc first. Crash-safe (atomic mv). --------
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if [ -f "$BASHRC" ]; then
  # Strip both modern marker block AND legacy unmarked block in one pass.
  awk -v mark="$MARK" '
    /^# >>> '"$MARK"' >>>$/ { skip=1; next }
    /^# <<< '"$MARK"' <<<$/ { skip=0; next }
    /ai-usage-bar — terminal usage bar/ { skip=1; legacy=1; next }
    legacy && /^fi$/ { skip=0; legacy=0; next }
    !skip { print }
  ' "$BASHRC" > "$TMP"
else
  : > "$TMP"
fi

cat >> "$TMP" <<'EOF'

# >>> ai-usage-bar >>>
# ai-usage-bar — terminal usage bar for AI subscriptions
if [ -x "$HOME/projects/ai-usage/ai-usage" ]; then
    _ai_bar() {
        local f=/tmp/ai-usage.bar
        if [ ! -f "$f" ] || [ $(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) )) -gt 60 ]; then
            "$HOME/projects/ai-usage/ai-usage" --bar > "$f" 2>/dev/null || true
        fi
        local bar
        bar=$(<"$f" 2>/dev/null || true)
        if [ -n "$bar" ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != "dumb" ]; then
            printf '\e7\e[%dG\e[36m%s\e[0m\e8' $(( $(tput cols 2>/dev/null || echo 80) - ${#bar} )) "$bar"
        fi
    fi
    case $PROMPT_COMMAND in
      *_ai_bar*) ;;
      *) PROMPT_COMMAND="_ai_bar;$PROMPT_COMMAND" ;;
    esac
fi
# <<< ai-usage-bar <<<
EOF
mv "$TMP" "$BASHRC"

# ----- Step 2: fetch latest source (best-effort). -------------------------
if [ -d "$REPO/.git" ]; then
  echo "==> updating existing install"
  # Fast-forward only; if diverged, reset to origin so the install always
  # reflects the canonical files. Local edits should have been committed
  # via `git add && git commit` before running install.
  if ! git -C "$REPO" pull --ff-only 2>/dev/null; then
    branch=$(git -C "$REPO" symbolic-ref --short HEAD 2>/dev/null || echo main)
    if git -C "$REPO" fetch origin "$branch" 2>/dev/null; then
      git -C "$REPO" reset --hard "origin/$branch" 2>/dev/null \
        || echo "    (fetch failed — using local copy. Resolve: cd $REPO && git pull --rebase)"
    fi
  fi
else
  echo "==> cloning $REMOTE"
  mkdir -p "$(dirname "$REPO")"
  git clone "$REMOTE" "$REPO"
fi
chmod +x "$REPO/ai-usage"

cat <<INFO

Done.
  Test:           $REPO/ai-usage --bar
  Reload shell:    source ~/.bashrc   (or open a new one)
  Manual keys:     ~/.config/ai-usage/<short>   (mode 600)
  Auto-detect:     opencode / claude-code / codex / github-copilot
  All flags:       --bar (silent) | --json (machine) | --check (cron) | --help
INFO
