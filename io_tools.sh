#!/usr/bin/env bash
#
# TODO: Write file header
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

declare -i LINES COLUMNS TRANSVERSE SAGITTAL LIG_DBUG
readonly LIG_CACHE_DIR="${XDG_CACHE_HOME:=${HOME}/.cache}"

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

cleanup() {
  # 2J    Clear screen
  # m     Reset Colours 
  # ?25h  Show cursor
  # ?7h   Disable line wrapping
  # r     Reset scrolling region
  printf "\x1B\x9B%s" 2J m ?25h ?7h r 
  # Reset stty if modified
  [[ -n "$STTY_BAK" ]] && stty $STTY_BAK || echo "stty unset"
  nap 1
}

die() {
  cleanup
  # Output to stderr
  printf "%s: line %d: %s: %s.\n" ${BASH_SOURCE[1]} ${BASH_LINENO[0]} ${FUNCNAME[1]} "${1-Died}" >&2
  nap 3
}

get_size() {
  ((LIG_DBUG)) || {
    read -r LINES COLUMNS < <(stty size)
  } && ((LIG_DBUG&2)) && {
    ((LIG_DBUG<<=1))
    read -rp "Specify {LINES} {COLUMNS}: " LINES COLUMNS
    !((LINES)) || !((COLUMNS)) && die 'Parse Error'
  }
  #[[ -n $1 ]] && LINES=$1 && [[ -n $2 ]] && COLUMNS=$2
  TRANSVERSE=$(((LINES+1)>>1))
  SAGITTAL=$(((COLUMNS+1)>>1))
}

win_init() {
  # 2J    Clear screen
  # 31m   Foreground red
  # ?25l  Hide cursor
  # ?7l   Disable line wrapping
  printf "\x1B\x9B%s" 2J 31m ?25l ?7l
}

repeat()for((;rep++<$2;)){ printf "$1";}

nap() {
  local IFS # Reset IFS
  [[ -n "${_nap_fd:-}" ]] || { exec {_nap_fd}<> <(:); } 2>/dev/null
  read ${1:+-t "$1"} -u $_nap_fd || :
}

_dbug_alignment() {
    printf "\x1B\x9B%s;%sH\xE2\x94\xAC %s" $((TRANSVERSE-2)) ${SAGITTAL} $((TRANSVERSE-2))
    printf "\x1B\x9B%s;H\xE2\x95\x9F %s" $((TRANSVERSE-1)) $((TRANSVERSE-1)) 
    printf "\x1B\x9B%sG\xE2\x94\x9C %s" ${SAGITTAL} ${SAGITTAL}
}

part_display() {
  local -i lines_odd=$(( LINES & 1 ))
  local -i cols_odd=$(( COLUMNS & 1 ))
  t_top="\xE2\x95\xa8" 
  t_bot="\xE2\x95\xa5" 
  #((lines_odd))
  for (( i = 0; i < SAGITTAL - 1; i++ )); do
    printf "\x1B\x9B${TRANSVERSE};$(( SAGITTAL - i))H\xE2\x94\x80"
    printf "\x1B\x9B${TRANSVERSE};$(( SAGITTAL + i + !cols_odd))H\xE2\x94\x80"
    ((i<3)) && nap 2 || nap 0.003
  done
  printf "\x1B\x9B%s%b" "${TRANSVERSE};H" ${t_top} "${COLUMNS}G" ${t_top}
  printf "\x1B\x9B%s%b" "$((TRANSVERSE+1+li));H" ${t_bot} "${COLUMNS}G" ${t_bot}
}

draw_frame() {
  local -i i=${1:-1}
  local -i j=${2:-1}
  local -i m=${3:-$LINES}
  local -i n=${4:-$COLUMNS}
  local horz=$(repeat "\xE2\x95\x90" $((n - 2)))
  local vert="\xE2\x95\x91\x1B\x9B$((n-2))C\xE2\x95\x91"
  #       Cursor origin           ╔           ═           ╗
  printf "\x1B\x9B${i};${j}H\xE2\x95\x94${horz}\xE2\x95\x97"
  # Every line but first and last ║                       ║
  for((;offset++<m-2;)){ printf "\x1B\x9B$((i+offset));${j}H${vert}";}
  #       origin + 1 down         ╚           ═           ╝
  printf "\x1B\x9B$((i+m-1));${j}H\xE2\x95\x9A${horz}\xE2\x95\x9D"
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
  trap 'die "Interrupted"' SIGINT EXIT
  [[ $1 == -d ]] && LIG_DBUG=1 || LIG_DBUG=0
  mod_stty
  get_size
  echo $LINES $COLUMNS
  nap 3
  exit 0
  win_init
  draw_frame
  #dive
  part_display
  nap 1
  exit 0
}
main "$@"
