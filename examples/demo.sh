#!/usr/bin/env bash
# Render every theme with the live repo git state.
set -e
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/.." && pwd)
for t in adventure aurora starcommand minimal; do
  printf '\n\033[1m════ %s ════\033[0m\n' "$t"
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 4.8 (1M)"},"effort":{"level":"high"},"context_window":{"total_input_tokens":630000,"total_output_tokens":0,"context_window_size":1000000,"used_percentage":63},"cost":{"total_cost_usd":1.42,"total_duration_ms":933000,"total_lines_added":156,"total_lines_removed":23},"pr":{"number":42,"review_state":"approved"},"rate_limits":{"five_hour":{"used_percentage":41},"seven_day":{"used_percentage":9}}}' "$root" \
    | ADVENTURELINE_THEME="$t" bash "$root/statusline.sh"
  echo
done
