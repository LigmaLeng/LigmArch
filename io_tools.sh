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
  for((;;)){ read "${TTIN_OPTS[@]}" -N1; (($?>128)) || exit 1;}
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
  for ((i=0; i < SAGITTAL-1; i++)); {
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
  for ((i=0; i < (TRANSVERSE>>2) - (LINES&1); i++)); {
    printf "\x1B\x9B%s" A M B 2L A
    nap 0.015
  }
}

exit_sequence() {
  local exit_query='Abort setup process'
  local exit_opts=('(Y|y)es' '(N|n)o')
  display_cleave
  printf "\x1B\x9B$((TRANSVERSE-(LINES&1)));${SAGITTAL}H\x1B7"
  ((COLUMNS&1)) && exit_query+=' ' && exit_opts[0]+=' '
  exit_query+='?' && exit_opts="${exit_opts[0]}   ${exit_opts[1]}"
  printf "\x1B\x9B$(((${#exit_query}>>1)-!(COLUMNS&1)))D${exit_query}"
  printf "\x1B8\x1BD\x1B\x9B$(((${#exit_opts}>>1)-!(COLUMNS&1)))D${exit_opts}"
  for((;;)); {
    read "${TTIN_OPTS[@]}" -N1
    (($?>128)) && continue
    case "${REPLY}" in
      Y|y) exit 0;;
      N|n) break;;
      *) continue;;
    esac
  }
  display_init
}

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
#  0 if ESC key pressed
#  1 if ENTER key pressed
########################################
ttin_parse() {
  local str
  # Infinite loop
  for ((;;)); {
    read "${TTIN_OPTS[@]}" -N1
    # Continue loop if read times out from lack of input
    (($?>128)) && continue
    # Handling escape characters
    [[ "${REPLY}" == $'\x1B' ]] && {
      # Handling control sequence indicators ('[' + sequence)
      read "${TTIN_OPTS[@]}" -N1
      [[ "${REPLY}" != "[" ]] && return 0 || read "${TTIN_OPTS[@]}" -N2
      case "${REPLY}" in
        A) printf "\x1B8U";; # dpad up
        B) printf "\x1B8D";; # dpad down
        C) printf "\x1B8R";; # dpad right
        D) printf "\x1B8L";; # dpad left
        '1~') printf "\x1B8HOME";; # home
        '3~') printf "\x1B8DEL";; # del
        '4~') printf "\x1B8END";; # end
        '5~') printf "\x1B8PG_U";; # pg up
        '6~') printf "\x1B8PG_D";; # pg down
        *) printf "Key disabled";;
      esac
    } || {
      case "${REPLY}" in
        $'\x7F'|$'\x08')
          [ -z "${str}" ] || str=${str:0:-1}
        ;;
        $'\n') return 1;; # newline (stty set to icrnl)
      esac
      str=$str"$1"
      printf "\x1B8$str"
    }
  }
}

keymap_handler() {
  local keymaps=($(localectl list-keymaps))
  win_draw 2 $SAGITTAL $((LINES-2)) $((SAGITTAL-1))
  ttin_parse
  #printf "\x1B8\x1B\x9B$((SAGITTAL-3))@"
  #printf "%s\x1B8\x1BD\x1B7" ${keymaps[1]}
}

main() {
  trap 'display_clean' EXIT
  trap 'stty_sizeup; win_draw' SIGWINCH
  trap 'exit_sequence' SIGINT
  TTIN_OPTS=(-rs) && ((BASH_VERSINFO[0] > 3)) && TTIN_OPTS+=(-t 0.02)
  readonly TTIN_OPTS
  [[ $1 == -d ]] && test_size || stty_mod
  display_init
  keymap_handler
  exit_sequence
}
main "$@"
