#!/usr/bin/env bash

# Colors
MAGENTA='\033[0;35m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
DIM='\033[2m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RESET='\033[0m'

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // "?"')
model=$(echo "$input" | jq -r '.model.display_name // "?"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
cwd="${cwd/#$HOME/~}"

# Build context display
if [ -n "$used_pct" ]; then
  # Choose color based on usage
  if (( $(echo "$used_pct > 75" | bc -l) )); then
    ctx_color="$RED"
  elif (( $(echo "$used_pct > 50" | bc -l) )); then
    ctx_color="$YELLOW"
  else
    ctx_color="$GREEN"
  fi
  ctx_str="${ctx_color}ctx: ${used_pct}%% used${RESET}"
else
  ctx_str="${DIM}ctx: --${RESET}"
fi

# Build ccusage display (cached for 60s to avoid slow refreshes)
CACHE_FILE="/tmp/.ccusage_statusline_cache"
CACHE_TTL=60

usage_str=""
if command -v ccusage &>/dev/null; then
  now=$(date +%s)
  cache_valid=false
  if [ -f "$CACHE_FILE" ]; then
    cache_time=$(head -1 "$CACHE_FILE")
    if (( now - cache_time < CACHE_TTL )); then
      cache_valid=true
    fi
  fi

  if [ "$cache_valid" = true ]; then
    cached=$(tail -n +2 "$CACHE_FILE")
    block_cost=$(echo "$cached" | sed -n '1p')
    block_tokens=$(echo "$cached" | sed -n '2p')
    daily_cost=$(echo "$cached" | sed -n '3p')
  else
    today=$(date +%Y-%m-%d)

    block_json=$(ccusage blocks --active --json 2>/dev/null)
    block_cost=$(echo "$block_json" | jq -r '(.blocks // []) | map(select(.isActive == true)) | first | .costUSD // 0' 2>/dev/null)
    block_tokens=$(echo "$block_json" | jq -r '(.blocks // []) | map(select(.isActive == true)) | first | .totalTokens // 0' 2>/dev/null)

    daily_json=$(ccusage --json 2>/dev/null)
    daily_cost=$(echo "$daily_json" | jq -r --arg d "$today" '(.daily // []) | map(select(.date == $d)) | first | .totalCost // 0' 2>/dev/null)

    block_cost="${block_cost:-0}"
    block_tokens="${block_tokens:-0}"
    daily_cost="${daily_cost:-0}"

    { echo "$now"; echo "$block_cost"; echo "$block_tokens"; echo "$daily_cost"; } > "$CACHE_FILE"
  fi

  # Format tokens: show as K with 1 decimal if >= 1000
  if (( $(echo "$block_tokens >= 1000" | bc -l) )); then
    tok_fmt=$(echo "scale=1; $block_tokens / 1000" | bc)
    tok_str="${tok_fmt}K tok"
  else
    tok_str="${block_tokens} tok"
  fi

  # Format costs
  block_cost_fmt=$(printf "%.2f" "$block_cost")
  daily_cost_fmt=$(printf "%.2f" "$daily_cost")

  usage_str="${CYAN}\$${block_cost_fmt} block · ${tok_str} · \$${daily_cost_fmt} today${RESET}"
fi

if [ -n "$usage_str" ]; then
  printf "${MAGENTA}${cwd}${RESET}  ${BLUE}${model}${RESET}  ${ctx_str}  ${usage_str}"
else
  printf "${MAGENTA}${cwd}${RESET}  ${BLUE}${model}${RESET}  ${ctx_str}"
fi
