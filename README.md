# ai-usage-bar — tmux status-line + zsh RPROMPT helper.
# Single line. Drop a key per provider into ~/.config/ai-usage/<short>.
# Tmux:   set -g status-right '#(ai-usage --bar)'
# Zsh:    source ~/projects/ai-usage/zsh.sh   # adds to RPROMPT
# ponytail: 4s timeout per provider — slow bar == bad bar.

# 5 providers known (lazy add): openrouter, anthropic, openai, copilot, agy
# Provider short-names must match a file in ~/.config/ai-usage/<name>