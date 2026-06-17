#!/bin/bash
input=$(cat)

DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
MODEL=$(echo "$input" | jq -r '.model.display_name')
# Drop a trailing parenthetical like " (1M context)" -- the context size
# isn't useful in the bar.
MODEL=${MODEL% (*}

USED=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

RL5=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
RL7=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
RL5_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
RL7_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

RESET='\033[0m'
BOLD='\033[1m'

# 256-color foreground / background helpers
fg() { printf '\033[38;5;%sm' "$1"; }
bg() { printf '\033[48;5;%sm' "$1"; }

# Pick a color for the context bar based on percentage: green -> yellow -> red
ctx_color() {
  local p=${1%.*}
  if   [ "$p" -lt 50 ]; then echo 78    # green
  elif [ "$p" -lt 75 ]; then echo 220   # yellow
  elif [ "$p" -lt 90 ]; then echo 208   # orange
  else                       echo 196   # red
  fi
}

# Build a filled/empty block bar of given width for a percentage
bar() {
  local pct=${1%.*} width=$2 color=$3
  local filled=$(( pct * width / 100 ))
  [ "$filled" -gt "$width" ] && filled=$width
  local empty=$(( width - filled ))
  printf '%b' "$(fg "$color")"
  for ((i=0;i<filled;i++)); do printf '█'; done
  printf '%b' "$(fg 240)"
  for ((i=0;i<empty;i++)); do printf '░'; done
  printf '%b' "$RESET"
}

# --- directory segment (white on blue) ---
seg_dir="$(bg 24)$(fg 231)$BOLD  $(basename "$DIR") $RESET"

# --- model segment (white on purple) ---
seg_model="$(bg 54)$(fg 231)  $MODEL $RESET"

# --- tailscale node segment (white on teal) ---
# Which tailnet node this machine is. We read DNSName's first label
# rather than HostName because DNSName carries the real tailnet name,
# including the "-1" suffix Tailscale appends on a name collision.
# `tailscale status` hits the local daemon on every render, so cache the
# resolved name for 5 min -- it effectively never changes mid-session.
seg_ts=""
if command -v tailscale >/dev/null 2>&1; then
  ts_cache="${TMPDIR:-/tmp}/.claude-ts-node"
  if [ -f "$ts_cache" ] && [ "$(( $(date +%s) - $(stat -c %Y "$ts_cache") ))" -lt 300 ]; then
    ts_node=$(cat "$ts_cache")
  else
    ts_node=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | cut -d. -f1)
    printf '%s' "$ts_node" > "$ts_cache"
  fi
  [ -n "$ts_node" ] && seg_ts="$(bg 23)$(fg 231) 󰒓 $ts_node $RESET"
fi

# --- context segment ---
if [ -n "$USED" ]; then
  C=$(ctx_color "$USED")
  seg_ctx=" $(bar "$USED" 12 "$C") $(fg "$C")$BOLD${USED}%$RESET"
else
  seg_ctx=""
fi

# --- rate-limit usage segment (5h / 7d, colored by how much is consumed;
# labels dropped -- the reset value disambiguates: a time is the 5h window,
# a day is the 7d window) ---
seg_usage=""
if [ -n "$RL5" ] || [ -n "$RL7" ]; then
  seg_usage=" "
  if [ -n "$RL5" ]; then
    seg_usage="$seg_usage$(fg "$(ctx_color "$RL5")")$(printf '%.0f' "$RL5")%"
    [ -n "$RL5_RESET" ] && seg_usage="$seg_usage$(fg 240) $(date -d "@$RL5_RESET" +'%-I:%M%P')"
  fi
  if [ -n "$RL7" ]; then
    seg_usage="$seg_usage $(fg "$(ctx_color "$RL7")")$(printf '%.0f' "$RL7")%"
    [ -n "$RL7_RESET" ] && seg_usage="$seg_usage$(fg 240) $(date -d "@$RL7_RESET" +'%a')"
  fi
  seg_usage="$seg_usage$RESET"
fi

printf '%b%b%b\n' "$seg_ts" "$seg_dir" "$seg_model"
# Second row: rate-limit usage, then the context bar at the end. Trim the
# leading space the first present segment carries so it sits at the left
# margin. Only print when there's something to show.
row2="${seg_usage}${seg_ctx}"
[ -n "$row2" ] && printf '%b\n' "${row2# }"
