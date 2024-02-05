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
declare -a TTIN_OPTS
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

die() {
  local -a bash_trace=(${BASH_SOURCE[1]} ${BASH_LINENO[0]} ${FUNCNAME[1]})
  display_clean
  printf "%s: line %d: %s: %s\n" ${bash_trace[@]} "${1-Died}" >&2
  printf "press any key to continue"
  for((;;)){ read "${TTIN_OPTS[@]}"; (($?>128)) || exit 1;}
}

echoes()for((i=0;i++<$2;)){ printf "$1";}

nap() {
  # Reset IFS
  local IFS
  # Open temp file descriptor if doesn't exist
  # and pipe a whole lot of nothing into it
  [[ -n "${dragon_scroll:-}" ]] || { exec {dragon_scroll}<> <(:);} 2>/dev/null
  # Attempt to read from empty file descriptor indefinitely if no timeout given
  read ${1:+-t "$1"} -u $dragon_scroll || :
}

stty_mod() {
  readonly STTY_BAK=$(stty -g)
  stty -nl -echo -icanon -ixon isig 
}

stty_sizeup() {
  ((OPT_TEST)) || read -r LINES COLUMNS < <(stty size)
  TRANSVERSE=$(((LINES+1)>>1))
  SAGITTAL=$(((COLUMNS+1)>>1))
}

test_size() {
  # Temp vars as invoking stty overrides values for LINES and COLUMNS
  local -a dim
  OPT_TEST=1
  read -ra dim -p "Enter display size in {LINES} {COLUMNS} (ex: 25 80): "
  stty_mod
  (( ${#dim[@]} )) || return 0
  !(( ${dim[0]} )) || !(( ${dim[1]} )) && die 'Parse Error'
  LINES=${dim[0]}
  COLUMNS=${dim[1]}
  return 0
}

win_draw() {
  local -i idx_y=${1:-1}
  local -i idx_x=${2:-1}
  local -i m=${3:-$LINES}
  local -i n=${4:-$COLUMNS}
  local -i offset=0
  local horz=$(echoes "\xE2\x95\x90" $((n - 2)))
  local vert="\xE2\x95\x91\x1B\x9B$((n-2))C\xE2\x95\x91"
  #       Cursor origin           ╔           ═           ╗
  printf "\x1B\x9B${idx_y};${idx_x}H\xE2\x95\x94${horz}\xE2\x95\x97"
  # Every line but first and last ║                       ║
  for((;offset++<m-2;)){ printf "\x1B\x9B$((idx_y+offset));${idx_x}H${vert}";}
  #       Last line off window    ╚           ═           ╝
  printf "\x1B\x9B$((idx_y+m-1));${idx_x}H\xE2\x95\x9A${horz}\xE2\x95\x9D"
  #       Bring cursor into window and bound scrolling region
  printf "\x1B\x9B$((idx_y+1));%s" "$((idx_y+m-2))r" "$((idx_x+1))H"
  #       Save cursor state for harmless convenience
  printf "\x1B7"
}

display_init() {
  stty_sizeup
  # 2J    Clear screen
  # 31m   Foreground red
  # ?25l  Hide cursor
  # ?7l   Disable line wrapping
  printf "\x1B\x9B%s" 2J 31m ?25l ?7l
  win_draw
}

display_clean() {
  # m     Reset Colours 
  # ?25h  Show cursor
  # ?7h   Disable line wrapping
  # 2J    Clear screen
  # r     Reset scrolling region
  printf "\x1B\x9B%s" m ?25h ?7h 2J r
  # Reset stty if modified
  [[ -n "$STTY_BAK" ]] && stty $STTY_BAK
}

display_cleave() {
  local fissure=$(echoes "\xE2\x94\x80" $((COLUMNS-2)))
  # Cursor on transverse plane and save cursor state
  printf "\x1B\x9B${TRANSVERSE};H\x1B7"
  # Grow fissure from from saggital plane laterally along transverse plane
  for ((i=0;i++<SAGITTAL-1;)); {
    printf "\x1B\x9B$(( SAGITTAL - i))G\xE2\x95\x90"
    printf "\x1B\x9B$(( SAGITTAL + i + !(COLUMNS&1) ))G\xE2\x95\x90"
    nap 0.004
  }
  # Ligate fissure
  echoes "\xE2\x95\xAC\x1B8" 2 && nap 0.1
  # Pilot cleavage and swap ligatures
  printf "\xE2\x95\xA8%b" $fissure "\n"
  printf "\xE2\x95\xA5%b" $fissure "\x1B8"
  # Widen pilot cleave if lines are odd
  # A M B L: up  delete_line  down  insert_line
  ((LINES&1)) && printf "\x1B\x9B%s" A M B L A
  # Continue widening
  for ((i=0;i++<(TRANSVERSE>>2)-(LINES&1);)); {
    printf "\x1B\x9B%s" A M B 2L A
    nap 0.015
  }
}

ttin_parse() {
  # Detecting escape characters
  [[ $1 == $'\x1B' ]] && {
    read "${TTIN_OPTS[@]}"
    # Detecting potential control sequence indicators ('[' + sequence)
    [[ "${REPLY}" != "[" ]] && die "esc" || read "${TTIN_OPTS[@]}"
    case "$sp" in
      A) echo "up";;
      B) echo "down";;
      C) echo "right";;
      D) echo "left";;
      *) exit 0;;
    esac
  }
    case $1 in
      $'\x7F'|$'\x08') [ -z "$str" ] || str=${str:0:-1};;
      $'\n') echo "ent";;
      ' ') echo "sp";;
      'q') die "q";;
    esac
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
  trap 'display_clean' EXIT
  trap 'stty_sizeup; win_draw' SIGWINCH
  trap 'die "interrupted"' SIGINT
  TTIN_OPTS=(-rsN1) && ((BASH_VERSINFO[0] > 3)) && TTIN_OPTS+=(-t 0.05)
  readonly TTIN_OPTS
  [[ $1 == -d ]] && test_size || stty_mod
  display_init
  for ((;;)){ read "${TTIN_OPTS[@]}" && ttin_parse "${REPLY}";}
  exit 0
}
main "$@"
