#!/usr/bin/env bash
# adventureline — Claude Code statusline (aligned grid + themed labels)
# by Adventure Labs · MIT. Layout/gradient: statusline-grid.py (same folder).
# Reads the Claude Code statusline JSON from stdin (schema v2.1.197).
#
#   LOCAL/VCS : Repo · Branch(dirty) · Sync · Path · PR · Worktree · Session · Agent
#   ENGINE    : Model · Effort · Context (bar + tokens + % used)
#   SESSION   : Cost · Burn $/h · Time · Lines ± · Limits
#
# Themes: adventure (default) · aurora · starcommand · minimal
#   pick via  $ADVENTURELINE_THEME  env,  ./theme.conf  file, or  adventureline theme <name>

input=$(cat)
export LC_NUMERIC=C   # decimal ponto, independente do locale do host (pt_*, de_*, etc.)
US=$'\037'   # unit separator (emoji␟label␟value)
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)

# ── Theme resolution: env → theme.conf → default ──────────────────────────────
theme="${ADVENTURELINE_THEME:-}"
[ -z "$theme" ] && [ -f "$SCRIPT_DIR/theme.conf" ] && theme=$(tr -d '[:space:]' < "$SCRIPT_DIR/theme.conf" 2>/dev/null)
[ -z "$theme" ] && theme="adventure"
case "$theme" in
  aurora)            TH_EMOJI=1; TH_BAR=1; TH_VALCOLOR=1; export AL_GRAD="52,211,153;34,211,238;167,139,250"; export AL_LABELSTYLE=gradient;;
  starcommand|star)  TH_EMOJI=1; TH_BAR=1; TH_VALCOLOR=1; export AL_GRAD="96,141,204;226,232,240;148,163,184"; export AL_LABELSTYLE=gradient;;
  minimal|min)       TH_EMOJI=0; TH_BAR=0; TH_VALCOLOR=0; export AL_GRAD="";                                  export AL_LABELSTYLE=bold;;
  adventure|*)       TH_EMOJI=1; TH_BAR=1; TH_VALCOLOR=1; export AL_GRAD="37,99,235;124,58,237;220,38,38";    export AL_LABELSTYLE=gradient;;
esac

human_tok() {
  awk -v t="$1" 'BEGIN{
    if (t>=1000000) { m=t/1000000; if (m==int(m)) printf "%dM", m; else printf "%.1fM", m; }
    else if (t>=1000) printf "%dk", (t/1000)+0.5;
    else printf "%d", t;
  }'
}
human_dur() {
  awk -v ms="$1" 'BEGIN{ s=int(ms/1000);
    if (s<60) printf "%ds", s; else if (s<3600) printf "%dm", int(s/60);
    else printf "%dh%02dm", int(s/3600), int((s%3600)/60); }'
}
human_eta() {
  now=$(date +%s)
  awk -v target="$1" -v now="$now" 'BEGIN{ d=target-now;
    if (d<=0){printf "0m";exit} if (d<60){printf "<1m";exit}
    if (d<3600){printf "%dm",int(d/60);exit} printf "%dh%02dm",int(d/3600),int((d%3600)/60); }'
}

# paint SGRCODE TEXT → colored (color themes) or plain (minimal)
paint() { if [ "$TH_VALCOLOR" = 1 ]; then printf '\033[%sm%s\033[0m' "$1" "$2"; else printf '%s' "$2"; fi; }
# cell EMOJI LABEL VALUE → "emoji␟label␟value" (emoji dropped when theme has none)
cell() { local e="$1"; [ "$TH_EMOJI" = 1 ] || e=""; printf '%s%s%s%s%s' "$e" "$US" "$2" "$US" "$3"; }

# ── One jq extracts everything (perf). Join with 0x1f so `read` keeps empties ──
IFS=$'\037' read -r dir pr_num pr_state wt wtb sname aname model effort \
  in_tok out_tok cw_size used_pct cost dur_ms add del five five_reset week \
  < <(echo "$input" | jq -r '[
    (.workspace.current_dir // .cwd // ""),
    (.pr.number // ""), (.pr.review_state // ""),
    (.worktree.name // ""), (.worktree.branch // ""),
    (.session_name // ""), (.agent.name // ""),
    (.model.display_name // ""), (.effort.level // ""),
    (.context_window.total_input_tokens // 0),
    (.context_window.total_output_tokens // 0),
    (.context_window.context_window_size // 200000),
    (.context_window.used_percentage // ""),
    (.cost.total_cost_usd // ""), (.cost.total_duration_ms // ""),
    (.cost.total_lines_added // 0), (.cost.total_lines_removed // 0),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // "")
  ] | map(tostring) | join("")' 2>/dev/null)

l1=(); l2=(); l3=()

# ══ LINE 1 — LOCAL / VCS ══════════════════════════════════════════════════════
git_root=""; git_branch=""; git_dirty=""; ahead=""; behind=""
if [ -n "$dir" ] && [ -d "$dir" ]; then
  git_root=$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
  git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -n "$git_root" ]; then
    dc=$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    [ "${dc:-0}" -gt 0 ] && git_dirty="*${dc}"
    counts=$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
    if [ -n "$counts" ]; then behind=$(echo "$counts" | awk '{print $1}'); ahead=$(echo "$counts" | awk '{print $2}'); fi
  fi
fi
repo_name=""; [ -n "$git_root" ] && repo_name=$(basename "$git_root")
rel_path=""; { [ -n "$git_root" ] && [ "$dir" != "$git_root" ]; } && rel_path="${dir#"$git_root"/}"

if [ -n "$repo_name" ]; then
  l1+=("$(cell '📁' 'Repo' "$(paint '1;34' "$repo_name")")")
  if [ -n "$git_branch" ] && [ "$git_branch" != "HEAD" ]; then
    bval="$(paint '35' "$git_branch")"; [ -n "$git_dirty" ] && bval="${bval}$(paint '33' "$git_dirty")"
    l1+=("$(cell '🌿' 'Branch' "$bval")")
  fi
  sync=""
  [ -n "$ahead" ]  && [ "$ahead"  -gt 0 ] 2>/dev/null && sync="${sync}⇡${ahead}"
  [ -n "$behind" ] && [ "$behind" -gt 0 ] 2>/dev/null && sync="${sync}⇣${behind}"
  [ -n "$sync" ] && l1+=("$(cell '🔃' 'Sync' "$(paint '36' "$sync")")")
  [ -n "$rel_path" ] && l1+=("$(cell '📂' 'Path' "$(paint '2' "$rel_path")")")
elif [ -n "$dir" ]; then
  l1+=("$(cell '📁' 'Dir' "$(paint '1;34' "$(basename "$dir")")")")
fi

if [ -n "$pr_num" ]; then
  [ -z "$pr_state" ] && pr_state="open"
  case "$pr_state" in approved) pc='32';; changes_requested) pc='31';; draft) pc='2';; *) pc='33';; esac
  l1+=("$(cell '🔀' 'PR' "$(paint "$pc" "#$pr_num $pr_state")")")
fi
if [ -n "$wt" ]; then [ -n "$wtb" ] && wt="${wt}@${wtb}"; l1+=("$(cell '🌲' 'Worktree' "$(paint '33' "$wt")")"); fi
[ -n "$sname" ] && l1+=("$(cell '🏷️' 'Session' "$(paint '37' "$sname")")")
[ -n "$aname" ] && l1+=("$(cell '🕵️' 'Agent' "$(paint '2' "$aname")")")

# ══ LINE 2 — ENGINE ═══════════════════════════════════════════════════════════
[ -n "$model" ] && l2+=("$(cell '🤖' 'Model' "$(paint '1;36' "$model")")")
if [ -n "$effort" ] && [ "$effort" != "medium" ]; then l2+=("$(cell '⚡' 'Effort' "$(paint '35' "$effort")")"); fi
ctx_tok=$(( ${in_tok:-0} + ${out_tok:-0} )); [ -z "$cw_size" ] && cw_size=200000
if [ "$ctx_tok" -gt 0 ]; then
  if [ -z "$used_pct" ]; then used_pct=$(awk -v c="$ctx_tok" -v s="$cw_size" 'BEGIN{ if(s>0) printf "%.0f", c/s*100; else print 0}')
  else used_pct=$(printf '%.0f' "$used_pct"); fi
  if   [ "$used_pct" -ge 80 ] 2>/dev/null; then cc='31'
  elif [ "$used_pct" -ge 50 ] 2>/dev/null; then cc='33'; else cc='32'; fi
  toks="$(human_tok "$ctx_tok")/$(human_tok "$cw_size")"
  ctxval=""
  if [ "$TH_BAR" = 1 ]; then
    bar=$(awk -v p="$used_pct" 'BEGIN{ n=int(p/10+0.5); if(n>10)n=10; if(n<0)n=0;
      for(i=0;i<n;i++) printf "█"; e="\033[2m"; for(i=n;i<10;i++) printf "%s░",(i==n?e:""); }')
    ctxval="$(paint "$cc" "$bar") "
  fi
  ctxval="${ctxval}$(paint "$cc" "$toks") $(paint '2' "(${used_pct}%)")"
  l2+=("$(cell '🧠' 'Context' "$ctxval")")
fi

# ══ LINE 3 — SESSION ══════════════════════════════════════════════════════════
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
  l3+=("$(cell '💰' 'Cost' "$(paint '1;32' "\$$(printf '%.2f' "$cost")")")")
  if [ -n "$dur_ms" ] && [ "$dur_ms" -gt 60000 ] 2>/dev/null; then
    burn=$(awk -v c="$cost" -v ms="$dur_ms" 'BEGIN{ h=ms/3600000; if(h>0) printf "%.2f", c/h; else print 0}')
    l3+=("$(cell '🔥' 'Burn' "$(paint '2' "\$$burn/h")")")
  fi
fi
[ -n "$dur_ms" ] && [ "$dur_ms" -gt 0 ] 2>/dev/null && l3+=("$(cell '⏱️' 'Time' "$(paint '2' "$(human_dur "$dur_ms")")")")
if [ "${add:-0}" -gt 0 ] 2>/dev/null || [ "${del:-0}" -gt 0 ] 2>/dev/null; then
  l3+=("$(cell '✏️' 'Lines' "$(paint '32' "+$add") $(paint '31' "-$del")")")
fi
if [ -n "$five" ] || [ -n "$week" ]; then
  rl=()
  if [ -n "$five" ]; then fs="5h $(printf '%.0f' "$five")%"; [ -n "$five_reset" ] && fs="${fs} ↻$(human_eta "$five_reset")"; rl+=("$fs"); fi
  [ -n "$week" ] && rl+=("7d $(printf '%.0f' "$week")%")
  rlstr=$(IFS='·'; echo "${rl[*]}" | sed 's/·/ · /g')
  l3+=("$(cell '⏳' 'Limits' "$(paint '33' "$rlstr")")")
fi

# ══ Emit grid ═════════════════════════════════════════════════════════════════
term_cols=$(tput cols 2>/dev/null); [ -z "$term_cols" ] && term_cols="${COLUMNS:-80}"
if [ "$term_cols" -ge 110 ] 2>/dev/null; then NCOLS=3; else NCOLS=2; fi
COLBUDGET=$(( term_cols / NCOLS - 3 )); [ "$COLBUDGET" -lt 20 ] && COLBUDGET=20

GRID="$SCRIPT_DIR/statusline-grid.py"; [ -f "$GRID" ] || GRID="$HOME/.claude/statusline-grid.py"
if [ -f "$GRID" ] && command -v python3 >/dev/null 2>&1; then
  {
    for c in "${l1[@]}"; do printf '%s\n' "$c"; done; printf '\036\n'
    for c in "${l2[@]}"; do printf '%s\n' "$c"; done; printf '\036\n'
    for c in "${l3[@]}"; do printf '%s\n' "$c"; done
  } | python3 "$GRID" "$NCOLS" "$COLBUDGET"
else
  first=1
  for an in l1 l2 l3; do
    eval "set -- \"\${${an}[@]}\""
    line=""
    for p in "$@"; do
      [ -z "$p" ] && continue
      disp=$(printf '%s' "$p" | awk -F'\037' '{ if($1=="") printf "%s: %s",$2,$3; else printf "%s %s: %s",$1,$2,$3 }')
      if [ -z "$line" ]; then line="$disp"; else line="${line}  |  ${disp}"; fi
    done
    [ -z "$line" ] && continue
    if [ "$first" -eq 1 ]; then printf '%s' "$line"; first=0; else printf '\n%s' "$line"; fi
  done
fi
