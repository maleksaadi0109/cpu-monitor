#!/usr/bin/env bash

declare -a current=()
declare -a previous=()
BAR_LENGTH=40
DELAY=1
R=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'
C_TITLE=$'\e[1;36m'
C_KEY=$'\e[1;37m'
C_VAL=$'\e[0;33m'
C_BOX=$'\e[2;37m'
C_HEAD=$'\e[1;35m'
C_LOW=$'\e[32m'
C_MID=$'\e[33m'
C_HIGH=$'\e[31m'
COLS=$(tput cols 2>/dev/null || echo 80)
trap 'COLS=$(tput cols 2>/dev/null || echo 80)' WINCH

detect-unicode() {
  [[ "${CPUMON_ASCII:-}" == "1" ]] && return 1
  [[ "${CPUMON_UNICODE:-}" == "1" ]] && return 0
  local lang="${LANG:-}${LC_ALL:-}${LC_CTYPE:-}"
  if [[ "$lang" =~ [Uu][Tt][Ff]-?8 ]] && [[ "$TERM" != "linux" ]] && [[ "$TERM" != "dumb" ]]; then
    return 0
  fi
  return 1
}

if detect-unicode; then
  B_TL='╔' B_TR='╗' B_BL='╚' B_BR='╝'
  B_H='═' B_V='║' B_ML='╠' B_MR='╣'
  B_HL='─'
else
  B_TL='+' B_TR='+' B_BL='+' B_BR='+'
  B_H='=' B_V='|' B_ML='+' B_MR='+'
  B_HL='-'
fi

repeat-char() {
  local char=$1 count=$2
  (( count <= 0 )) && return
  local result
  printf -v result '%*s' "$count" ''
  printf '%s' "${result// /$char}"
}

get-os-info() {
  local target=$1
  if [[ -f /etc/os-release ]]; then
    grep -E "^${target}=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'"
  fi
}

get-ascii-art() {
  local id
  id=$(get-os-info "ID")
  
  case "${id,,}" in
    ubuntu)
      printf '%s\n' \
        "         _   " \
        "     ---(_)  " \
        " _/  ---  \  " \
        "(_) |   |    " \
        "  \  --- _/  " \
        "     ---(_)  "
      ;;
    debian)
      printf '%s\n' \
        "  _____      " \
        " /  __ \     " \
        "|  /    |    " \
        "|  \____-    " \
        "-____  |     " \
        "      \ |    "
      ;;
    arch)
      printf '%s\n' \
        "      /\     " \
        "     /  \    " \
        "    /\  /\   " \
        "   /  \/  \  " \
        "  / Arch   \ " \
        " /___________\\"
      ;;
    fedora)
      printf '%s\n' \
        "   ______    " \
        "  / ____/    " \
        " / /_        " \
        "/ __/        " \
        "/_/ edora    " \
        "             "
      ;;
    *)
      printf '%s\n' \
        "   .---.     " \
        "  |o_o |     " \
        "  |:_/ |     " \
        " //   \ \    " \
        "(|     | )   " \
        "/\_   _/\    "
      ;;
  esac
}

get-sysinfo() {
  local kernel uptime_s uptime_fmt mem_total mem_avail mem_used mem_pct
  local load1 load5 load15 cpu_model cpu_count pretty_name
  kernel=$(uname -r 2>/dev/null)
  pretty_name=$(get-os-info "PRETTY_NAME")
  [[ -z "$pretty_name" ]] && pretty_name="Linux"
  if [[ -r /proc/uptime ]]; then
    read -r uptime_s _ < /proc/uptime
    uptime_s=${uptime_s%.*}
    local days=$(( uptime_s / 86400 ))
    local hrs=$(( (uptime_s % 86400) / 3600 ))
    local mins=$(( (uptime_s % 3600) / 60 ))
    uptime_fmt="${days}d ${hrs}h ${mins}m"
  else
    uptime_fmt="N/A"
  fi
  
  mem_total=0
  mem_avail=0
  if [[ -r /proc/meminfo ]]; then
    while IFS=':' read -r k v; do
      v="${v## }"
      v="${v%% kB}"
      v="${v// /}"
      case "$k" in
        MemTotal)     mem_total=$v ;;
        MemAvailable) mem_avail=$v ;;
      esac
    done < /proc/meminfo
  fi
  
  mem_used=$(( (mem_total - mem_avail) / 1024 ))
  local mem_total_mb=$(( mem_total / 1024 ))
  if (( mem_total > 0 )); then
    mem_pct=$(( 100 * (mem_total - mem_avail) / mem_total ))
  else
    mem_pct=0
  fi
  if [[ -r /proc/loadavg ]]; then
    read -r load1 load5 load15 _ < /proc/loadavg
  else
    load1="N/A" load5="" load15=""
  fi
  cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//')
  cpu_count=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 0)
  printf '%s\n' \
    "${C_KEY}HOST${R}    ${C_VAL}${HOSTNAME}${R}" \
    "${C_KEY}OS${R}      ${C_VAL}${pretty_name}${R}" \
    "${C_KEY}KERNEL${R}  ${C_VAL}${kernel}${R}" \
    "${C_KEY}UPTIME${R}  ${C_VAL}${uptime_fmt}${R}" \
    "${C_KEY}CPU${R}     ${C_VAL}${cpu_count}x ${cpu_model}${R}" \
    "${C_KEY}MEM${R}     ${C_VAL}${mem_used}/${mem_total_mb} MB (${mem_pct}%)${R}" \
    "${C_KEY}LOAD${R}    ${C_VAL}${load1}  ${load5}  ${load15}${R}"
}

read-proc() {
  if [[ ! -r /proc/stat ]]; then
    printf 'Error: /proc/stat is not readable\n' >&2
    return 1
  fi
  local key user nice system idle iowait irq softirq steal guest guest_nice
  while read -r key user nice system idle iowait irq softirq steal guest guest_nice; do
    [[ $key != cpu* || $key == cpu ]] && continue
    local busy=$(( user + nice + system + irq + softirq + steal ))
    local idle_t=$(( idle + iowait ))
    local num=${key#cpu}
    current[num]="$busy $idle_t"
  done < /proc/stat
}

copy-data() {
  previous=("${current[@]}")
}

render-bar() {
  local key=$1
  local busy1 idle1 busy2 idle2
  
  read -r busy1 idle1 <<< "${previous[$key]:-0 0}"
  read -r busy2 idle2 <<< "${current[$key]}"
  
  local busy=$(( busy2 - busy1 ))
  local idle=$(( idle2 - idle1 ))
  local total=$(( busy + idle ))
  (( total == 0 )) && total=1
  local usage=$(( 1000 * busy / total ))
  local int=$(( usage / 10 ))
  local frac=$(( usage % 10 ))
  local num_bars=$(( usage * BAR_LENGTH / 1000 ))
  local colour
  if (( int < 50 )); then colour=$C_LOW
  elif (( int < 80 )); then colour=$C_MID
  else colour=$C_HIGH
  fi
  local bar_fill bar_empty
  printf -v bar_fill  '%*s' "$num_bars" ''
  printf -v bar_empty '%*s' "$(( BAR_LENGTH - num_bars ))" ''
  bar_fill=${bar_fill// /|}
  bar_empty=${bar_empty// / }
  printf "${C_KEY}cpu%-3s${R} ${C_BOX}[${R}${colour}%-${BAR_LENGTH}s${R}${C_BOX}]${R} ${colour}%3d.%d%%${R}\n" \
    "$key" "${bar_fill}${bar_empty}" "$int" "$frac"
}

draw-frame() {
  local now
  printf -v now "%(%Y-%m-%dT%H:%M:%S)T" -1
  local title=" CPU MONITOR "
  local ts=" ${now} (Refresh: ${DELAY}s) "
  
  local pad=$(( COLS - ${#title} - ${#ts} - 2 ))
  (( pad < 0 )) && pad=0

  printf "${C_BOX}%s${R}${C_TITLE}%s${R}" "$B_TL" "$title"
  printf "${C_BOX}%s${R}" "$(repeat-char "$B_H" "$pad")"
  printf "${C_VAL}%s${R}${C_BOX}%s${R}\n" "$ts" "$B_TR"
  local -a art sysinfo
  mapfile -t art      < <(get-ascii-art)
  mapfile -t sysinfo  < <(get-sysinfo)
  local ESC=$'\e'
  
  local max_art_width=0
  for line in "${art[@]}"; do
    local visible
    visible=$(printf '%s' "$line" | sed "s/${ESC}\\[[0-9;]*[a-zA-Z]//g")
    (( ${#visible} > max_art_width )) && max_art_width=${#visible}
  done
  
  (( max_art_width < 13 )) && max_art_width=13
  local max=$(( ${#art[@]} > ${#sysinfo[@]} ? ${#art[@]} : ${#sysinfo[@]} ))
  local i
  for (( i=0; i<max; i++ )); do
    local art_line="${art[$i]:-}"
    local sys_line="${sysinfo[$i]:-}"
    
    local visible_art
    visible_art=$(printf '%s' "$art_line" | sed "s/${ESC}\\[[0-9;]*[a-zA-Z]//g")
    
    local pad_len=$(( max_art_width - ${#visible_art} ))
    (( pad_len < 0 )) && pad_len=0
    
    local padding_space
    printf -v padding_space '%*s' "$pad_len" ''
    
    printf "${C_BOX}%s${R}  ${art_line}${padding_space}   %s\n" "$B_V" "$sys_line"
  done

  local divider_pad=$(( COLS - 2 ))
  (( divider_pad < 0 )) && divider_pad=0
  printf "${C_BOX}%s%s%s${R}\n" "$B_ML" "$(repeat-char "$B_H" "$divider_pad")" "$B_MR"
  printf "${C_BOX}%s${R}  ${C_HEAD}CORES${R}\n" "$B_V"
  printf "${C_BOX}%s${R}\n" "$B_V"
  for key in "${!current[@]}"; do
    printf "${C_BOX}%s${R}  " "$B_V"
    render-bar "$key"
  done
  printf "${C_BOX}%s${R}\n" "$B_V"

  local hint="  [q] quit   [r] refresh rate   "
  local pad2=$(( COLS - ${#hint} - 2 ))
  (( pad2 < 0 )) && pad2=0
  printf "${C_BOX}%s${R}${DIM}%s%s${R}${C_BOX}%s${R}\n" "$B_BL" "$hint" "$(repeat-char "$B_HL" "$pad2")" "$B_BR"
}

cleanup() {
  printf '\e[?1049l'
  printf '\e[?25h'
  printf '\e[0m'
}

main() {
  if [[ ! -r /proc/stat ]]; then
    printf 'Error: /proc/stat not found. This script requires a Linux system with procfs.\n' >&2
    exit 1
  fi
  read-proc
  copy-data
  sleep 0.1
  trap cleanup EXIT INT TERM
  printf '\e[?1049h'
  printf '\e[?25l'
  while true; do
    read-proc
    
    local frame
    frame=$(draw-frame)
    printf '\e[H%s\e[J' "$frame"
    if read -r -s -n1 -t "$DELAY" key 2>/dev/null; then
      case "${key,,}" in
        q) break ;;
        r) 
          if [[ "$DELAY" == "1" ]]; then DELAY="2"
          elif [[ "$DELAY" == "2" ]]; then DELAY="5"
          elif [[ "$DELAY" == "5" ]]; then DELAY="0.5"
          else DELAY="1"
          fi
          ;;
      esac
    fi
    
    copy-data
  done
}

main "$@"
