#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')
effort=$(echo "$input" | jq -r '.effort.level // empty')
output_style=$(echo "$input" | jq -r '.output_style.name // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
rl_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rl_5h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rl_7d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
ctx_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
ctx_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
exceeds_200k=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')
used_tokens=$((ctx_in + ctx_out))

# Human token formatter: 327404 -> 327k, 1000000 -> 1M, 1250000 -> 1.3M
fmt_tok() {
  local t=$1
  if (( t >= 1000000 )); then
    awk -v t="$t" 'BEGIN{ v=t/1000000; if (v==int(v)) printf "%dM", v; else printf "%.1fM", v }'
  else
    printf "%dk" $(( (t + 500) / 1000 ))
  fi
}

# Get git info (skip optional locks for performance)
git_info=""
if git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$current_dir" -c core.useBuiltinFSMonitor=false rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ -n "$branch" ]]; then
    # Check for dirty state
    if ! git -C "$current_dir" -c core.useBuiltinFSMonitor=false diff --quiet 2>/dev/null || \
       ! git -C "$current_dir" -c core.useBuiltinFSMonitor=false diff --cached --quiet 2>/dev/null; then
      dirty="±"
    else
      dirty=""
    fi
    git_info="$branch$dirty"
  fi
fi

# Get directory (always show basename only)
dir_display=$(basename "$current_dir")

# Build vim mode indicator
vim_indicator=""
if [[ -n "$vim_mode" ]]; then
  if [[ "$vim_mode" == "NORMAL" ]]; then
    vim_indicator=" [N]"
  else
    vim_indicator=" [I]"
  fi
fi

# Build output style indicator
style_indicator=""
if [[ -n "$output_style" && "$output_style" != "default" ]]; then
  style_indicator=" [$output_style]"
fi

# Context fill color (green < 70, yellow 70-90, red >= 90)
used_int=${used_pct%.*}
if (( used_int >= 90 )); then
  ctx_color="31"  # Red
elif (( used_int >= 70 )); then
  ctx_color="33"  # Yellow
else
  ctx_color="32"  # Green
fi

# Effort color: spend dial (low/medium green, high yellow, xhigh/max red)
case "$effort" in
  low|medium) effort_color="32" ;;
  high)       effort_color="33" ;;
  xhigh|max)  effort_color="31" ;;
  *)          effort_color="37" ;;
esac

# Rate-limit colors: 5h (green <70, yellow <90) / 7d (green <50, yellow <80)
if [[ -n "$rl_5h" ]]; then
  if   (( rl_5h >= 90 )); then rl5_color="31"
  elif (( rl_5h >= 70 )); then rl5_color="33"
  else rl5_color="32"; fi
fi
if [[ -n "$rl_7d" ]]; then
  if   (( rl_7d >= 80 )); then rl7_color="31"
  elif (( rl_7d >= 50 )); then rl7_color="33"
  else rl7_color="32"; fi
fi

# Use printf with ANSI colors (dimmed for status line)
# Agnoster-inspired: blue for directory, cyan for git, magenta for model
SEP=" \033[2m|\033[0m "

printf "\033[2m\033[34m%s\033[0m" "$dir_display"
if [[ -n "$git_info" ]]; then
  printf "$SEP"
  printf "\033[2m\033[36m%s\033[0m" "$git_info"
fi
printf "$SEP"
printf "\033[2m\033[35m%s\033[0m" "$model_name"
# Reasoning effort (live, reflects /effort)
if [[ -n "$effort" ]]; then
  printf "$SEP"
  printf "\033[2m\033[${effort_color}m%s\033[0m" "$effort"
fi
# Context: used% + absolute headroom + long-context pricing flag
printf "$SEP"
printf "\033[${ctx_color}m%.0f%%\033[0m" "$used_pct"
if (( ctx_size > 0 )); then
  printf " \033[2m%s/%s\033[0m" "$(fmt_tok "$used_tokens")" "$(fmt_tok "$ctx_size")"
fi
if [[ "$exceeds_200k" == "true" ]]; then
  printf " \033[31m>200k\033[0m"
fi
# Lines changed (green for added, red for removed)
printf "$SEP"
printf "\033[32m+%d\033[0m/\033[31m-%d\033[0m" "$lines_added" "$lines_removed"
# Cost
printf "$SEP"
printf "\033[2m\$%.2f\033[0m" "$cost"
# Rate-limit windows: <pct> ↻ <reset time> (5h: HH:MM, 7d: Day HH:MM)
if [[ -n "$rl_5h" || -n "$rl_7d" ]]; then
  printf "$SEP"
  if [[ -n "$rl_5h" ]]; then
    printf "\033[${rl5_color}m%d%%\033[0m" "$rl_5h"
    [[ -n "$rl_5h_reset" ]] && printf "\033[2m ↻ %s\033[0m" "$(date -r "$rl_5h_reset" +%H:%M)"
  fi
  if [[ -n "$rl_7d" ]]; then
    [[ -n "$rl_5h" ]] && printf " \033[2m/\033[0m "
    printf "\033[${rl7_color}m%d%%\033[0m" "$rl_7d"
    [[ -n "$rl_7d_reset" ]] && printf "\033[2m ↻ %s\033[0m" "$(date -r "$rl_7d_reset" +"%a %H:%M")"
  fi
fi
if [[ -n "$style_indicator" ]]; then
  printf "$SEP"
  printf "\033[2m\033[33m%s\033[0m" "${style_indicator# }"
fi
if [[ -n "$vim_indicator" ]]; then
  printf "$SEP"
  printf "\033[2m\033[32m%s\033[0m" "${vim_indicator# }"
fi
