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

declare -i LINES COLUMNS TRANSVERSE SAGITTAL
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
  [[ -n "$STTY_BAK" ]] && stty $STTY_BAK
}

die() {
  # Output to stderr
  local -a bash_trace=(${BASH_SOURCE[1]} ${BASH_LINENO[0]} ${FUNCNAME[1]})
  printf "%s: line %d: %s: %s\n" ${bash_trace[@]} "${1-Died}" >&2
  printf "press any key to continue"
  read -rsN1
  exit 0
}

get_size() {
  ((OPT_TEST)) || read -r LINES COLUMNS < <(stty size)
  TRANSVERSE=$(((LINES+1)>>1))
  SAGITTAL=$(((COLUMNS+1)>>1))
}

test_prompt() {
  # Temp vars as invoking stty overrides values for LINES and COLUMNS
  local -a dim
  OPT_TEST=1
  read -ra dim -p "Enter display size in {LINES} {COLUMNS} (ex: 25 80): "
  mod_stty
  (( ${#dim[@]} )) || return 0
  !(( ${dim[0]} )) || !(( ${dim[1]} )) && die 'Parse Error'
  LINES=${dim[0]}
  COLUMNS=${dim[1]}
  return 0
}

win_init() {
  # 2J    Clear screen
  # 31m   Foreground red
  # ?25l  Hide cursor
  # ?7l   Disable line wrapping
  printf "\x1B\x9B%s" 2J 31m ?25l ?7l "2;$((LINES-1))r"
}

echoes()for((i=0;i++<$2;)){ printf "$1";}

nap() {
  local IFS # Reset IFS
  [[ -n "${_nap_fd:-}" ]] || { exec {_nap_fd}<> <(:); } 2>/dev/null
  read ${1:+-t "$1"} -u $_nap_fd || :
}

cleave_display() {
  local fissure=$(echoes "\xE2\x94\x80" $((COLUMNS-2)))
  # Cursor on transverse plane and save cursor state
  printf "\x1B\x9B${TRANSVERSE};H\x1B7"
  # Grow fissure from from saggital plane laterally along transverse plane
  for (( i=0; i < SAGITTAL-1; i++ )); do
    printf "\x1B\x9B$(( SAGITTAL - i))G\xE2\x95\x90"
    printf "\x1B\x9B$(( SAGITTAL + i + !(COLUMNS&1) ))G\xE2\x95\x90"
    nap 0.004
  done
  # Ligate fissure
  echoes "\xE2\x95\xAC\x1B8" 2 && nap 0.1
  # Pilot cleavage and swap ligatures
  printf "\xE2\x95\xA8%b" $fissure "\n"
  printf "\xE2\x95\xA5%b" $fissure "\x1B8"
  # Widen pilot cleave if lines are odd
  # A M B L: up  delete_line  down  insert_line
  ((LINES&1)) && printf "\x1B\x9B%s" A M B L A
  # Continue widening
  for (( i=0; i < (TRANSVERSE>>2)-(LINES&1); i++ )); do
    printf "\x1B\x9B%s" A M B 2L A
    nap 0.015
  done
}

draw_frame() {
  local -i idx_y=${1:-1}
  local -i idx_x=${2:-1}
  local -i m=${3:-$LINES}
  local -i n=${4:-$COLUMNS}
  local horz=$(echoes "\xE2\x95\x90" $((n - 2)))
  local vert="\xE2\x95\x91\x1B\x9B$((n-2))C\xE2\x95\x91"
  #       Cursor origin           ╔           ═           ╗
  printf "\x1B\x9B${idx_y};${idx_x}H\xE2\x95\x94${horz}\xE2\x95\x97"
  # Every line but first and last ║                       ║
  for((;offset++<m-2;)){ printf "\x1B\x9B$((idx_y+offset));${idx_x}H${vert}";}
  #       origin + 1 down         ╚           ═           ╝
  printf "\x1B\x9B$((idx_y+m-1));${idx_x}H\xE2\x95\x9A${horz}\xE2\x95\x9D"
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
  trap 'cleanup' EXIT
  trap 'get_size; draw_frame' SIGWINCH SIGCONT
  trap 'die "Interrupted"' SIGINT
  [[ $1 == -t ]] && test_prompt || mod_stty
  get_size
  win_init
  draw_frame
  #dive
  cleave_display
  nap 1
  exit 0
}
main "$@"
