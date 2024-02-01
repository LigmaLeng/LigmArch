#!/usr/bin/env bash
#
# TODO: Write file header

#≡ = \xe2\x89\xa1

########################################
#(INSERT FUNCTION DESCRIPTON)
#Globals:
#  (DELETE INCLUDING DECLARATION IF NONE)
#  eg:
#  BACKUP_DIR
#  SOMEDIR
#Arguments:
#  None
#Outputs:
#  (DELETE INCLUDING DECLARATION IF NONE)
#  eg: Writes location to stdout
#Returns:
#  (DELETE INCLUDING DECLARATION IF NONE)
#  eg: 0 if thing was deleted, non-zero on error
########################################
#readonly LIG_CACHE_DIR="${XDG_CACHE_HOME:=${HOME}/.cache}"
declare -i LINES COLUMNS

declare -A _OPTS=(
[keymap]="us"
[partition_type]="linux-lvm"
[kernel]="linux-lts"
[network]="network-manager"
[locale]="en-AU"
[username]=""
[hostname]=""
[rootpass]=""
[userpass]=""
)

mod_stty() {
  readonly STTY_BAK=$(stty -g)
  stty -nl -echo -icanon -ixon -isig 
}

reset_stty() {
  stty $STTY_BAK
}

get_size() {
  read -r LINES COLUMNS < <(stty size)
}

win_init() {
  # 2J    Clear screen
  # 31m   Foreground red
  # ?25l  Hide cursor
  # ?7l   Disable line wrapping
  printf "\x1B\x9B%s" 2J 31m ?25l ?7l
}

cleanup_display() {
  # 2J    Clear screen
  # m     Reset Colours 
  # ?25h  Show cursor
  # ?7h   Disable line wrapping
  # r     Reset scrolling region
  printf "\x1B\x9B%s" 2J m ?25h ?7h r 
}

nap() {
  local IFS # Reset IFS
  [[ -n "${_nap_fd:-}" ]] || { exec {_nap_fd}<> <(:); } 2>/dev/null
  read ${1:+-t "$1"} -u $_nap_fd || :
}

part_display() {
  local -i lines_odd=$(( LINES & 1 ))
  local -i cols_odd=$(( COLUMNS & 1 ))
  local -i lines_mid=$(( (LINES + 1) >> 1 ))
  local -i cols_mid=$(( (COLUMNS + 1) >> 1 ))

  t_top="\xE2\x95\xa8" 
  t_bot="\xE2\x95\xa5" 
  (($lines_odd)) && {
    glyph="\xE2\x95\x90"
  } || {
    glyph="\xE2\x94\x80\x1B\x9BB\x1B\x9BD\xE2\x94\x80"
  }

  for (( i = 0; i < cols_mid - 1; i++ )); do
    printf "\x1B\x9B${lines_mid};$(( cols_mid - i))H${glyph}"
    printf "\x1B\x9B${lines_mid};$(( cols_mid + i + !cols_odd))H${glyph}"
    nap 0.003
  done

  printf "\x1B\x9B%s%b" "${lines_mid};H" ${t_top} "${COLUMNS}G" ${t_top}
  printf "\x1B\x9B%s%b" "$((lines_mid+1+li));H" ${t_bot} "${COLUMNS}G" ${t_bot}
}

prompt_exit() {
  part_display
}
die() {
  reset_stty
  cleanup_display
  # Output to stderr
  printf "%s: line %d: %s: %s.\n" ${BASH_SOURCE[1]} ${BASH_LINENO[0]} ${FUNCNAME[1]} ${1-Died} >&2
  exit 0
}

repeat() {
  local tmpl="${2:--}"
  local str=""
  for (( i = 0; i < $1 ; i++ )); do str+=$tmpl; done
  printf "$str"
}

draw_frame() {
  local -i i=${1:-1}
  local -i j=${2:-1}
  local -i m=${3:-$LINES}
  local -i n=${4:-$COLUMNS}
  local horz=$(repeat $((n-2)) "\xE2\x95\x90")
  local vert="\xE2\x95\x91\x1B\x9B$((n-2))C\xE2\x95\x91"

  printf "\x1B\x9B${i};${j}H\xE2\x95\x94${horz}\xE2\x95\x97"
  printf "\x1B\x9B$((i+m-1));${j}H\xE2\x95\x9A${horz}\xE2\x95\x9D"
  for (( offset = 1; offset < m-1; offset++ )); do
    printf "\x1B\x9B$((i+offset));${j}H${vert}"
  done
}



dive() {
  local char
  local sp
  local str

  printf "\x1B\x9B2;2H"
  while read -rsN1 char; do
    [[ $char == $'\x1B' ]] && {
      die "esc" 
    }
    case $char in
      $'\x7F'|$'\x08') [ -z "$str" ] || str=${str:0:-1};;
      $'\n') echo "ent";;
      ' ') echo "sp";;
      'q') die "q";;
      'j') die "q";;
      'k') die "q";;
    esac
  done

    #        # Detecting control sequence indicators ('[' + sequence)
    #        # is broken down into multiple steps
    #        read -sn1 sp
    #        [ "$sp" != "[" ] && die
    #        read -sn1 sp
    #        case "$sp" in
    #            A) echo "up";;
    #            B) echo "down";;
    #            C) echo "right";;
    #            D) echo "left";;
    #            *) exit 0;;
    #        esac
    #    else
    #        str=$str"$char"
    #    fi
    #    clear
    #    echo "Search: $str"
    #    grep -im 10 "$str" lc.txt
    #done
}

main() {
  trap 'get_size; draw_frame' SIGWINCH SIGCONT
  trap 'die "Interrupted"' INT TERM EXIT
  get_size
  mod_stty
  win_init
  LINES=44
  draw_frame
  #printf "\x1B\x9B2;2H%s" "$(stty -a)"
  #dive
  part_display
  nap 1
  reset_stty
  exit 0
}
main "$@"
