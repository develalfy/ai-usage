# ai-usage — terminal usage bar for AI subscriptions.
# Usage: ai-usage [--bar]   # --bar prints without header (for status lines)
#
# Wire it: add this to your ~/.bashrc:
#   if [ -x "$HOME/projects/ai-usage/ai-usage" ]; then
#       _ai_bar() {
#           local f=/tmp/ai-usage.bar
#           [ $(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) )) -gt 60 ] \
#               && "$HOME/projects/ai-usage/ai-usage" --bar > "$f" 2>/dev/null
#           local bar=$(<"$f")
#           [ -n "$bar" ] && printf '\e7\e[%dG\e[36m%s\e[0m\e8' $(( $(tput cols) - ${#bar} )) "$bar"
#       }
#       PROMPT_COMMAND="_ai_bar;$PROMPT_COMMAND"
#   fi
#
# Drop one key file per provider into ~/.config/ai-usage/<short>, 0600:
#   openrouter, anthropic, openai, copilot
# ponytail: 4s timeout per provider — slow bar == bad bar.