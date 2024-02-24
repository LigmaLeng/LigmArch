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
readonly TTIN_OPTS=(-rs -t 0.02)
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
  [[ -n "${nap_fd:-}" ]] || { exec {nap_fd}<> <(:);} 2>/dev/null
  # Attempt to read from empty file descriptor indefinitely if no timeout given
  read ${1:+-t "$1"} -u $nap_fd || :
}

set_con() {
  # Backup stty settings for cleanup on exit
  readonly STTY_BAK=$(stty -g)
  # Undefining binding for suspend signal as it breaks during reading input
  # Other options explained in stty manpage
  stty -echo -icanon -ixon -icrnl isig susp undef
  # Select default (single byte character set) and lock G0 and G1 charsets
  printf "\x1B%s" '%@' '(K' ')K'
}

get_con_size() {
  ((OPT_TEST)) || read -r LINES COLUMNS < <(stty size)
  TRANSVERSE=$(((LINES+1)>>1))
  SAGITTAL=$(((COLUMNS+1)>>1))
}

test_size() {
  # Temp vars as invoking stty overrides values for LINES and COLUMNS
  local -a dim
  OPT_TEST=1
  read -ra dim -p "Enter display size in {LINES} {COLUMNS} (ex: 25 80): "
  set_con
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
  local horz=$(echoes "\xCD" $((n - 2)))
  local vert="\xBA\x9B$((n-2))C\xBA"
  #       Cursor origin and print top border
  printf "\x9B${idx_y};${idx_x}H\xC9${horz}\xBB"
  #       Print vertical borders on every line but first and last
  for((;offset++<m-2;)){ printf "\x9B$((idx_y+offset));${idx_x}H${vert}";}
  #       Print bottom border
  printf "\x9B$((idx_y+m-1));${idx_x}H\xC8${horz}\xBC"
  #       Bound scrolling region, bring cursor into window
  printf "\x9B$((idx_y+1));%s" "$((idx_y+m-2))r" "$((idx_x+1))H"
  #       Save cursor state
  printf "\x1B7"
}

display_init() {
  get_con_size
  # 2J    Clear screen
  # 31m   Foreground red
  # ?25l  Hide cursor
  # ?7l   Disable line wrapping
  printf "\x9B%s" 2J 31m ?25l ?7l
  win_draw
}

display_clean() {
  # m     Reset Colours 
  # ?25h  Show cursor
  # ?7h   Disable line wrapping
  # 2J    Clear screen
  # r     Reset scrolling region
  printf "\x9B%s" m ?25h ?7h 2J r
  # Return character set back to UTF-8
  printf "\x1B%%G"
  # Reset stty if modified
  [[ -n "$STTY_BAK" ]] && stty $STTY_BAK
}

display_cleave() {
  local fissure=$(echoes "\xC4" $((COLUMNS-2)))
  # Cursor on transverse plane
  printf "\x9B${TRANSVERSE};H"
  # Grow fissure from from saggital plane laterally along transverse plane
  for ((i=0; i < SAGITTAL-1; i++)); {
    printf "\x9B$(( SAGITTAL - i))G\xCD"
    printf "\x9B$(( SAGITTAL + i + !(COLUMNS&1) ))G\xCD"
    nap 0.003
  }
  # Ligate fissure
  echoes "\xCE\x0D" 2 && nap 0.1
  # Pilot cleavage and swap ligatures
  printf "\xD0%b" ${fissure} "\n"
  printf "\xD2%b" ${fissure} "\x9BA\x0D"
  # Widen pilot cleave if lines are odd
  # A M B L: up  delete_line  down  insert_line
  ((LINES&1)) && printf "\x9B%s" A M B L A
  # Continue widening
  for ((i=0; i < (TRANSVERSE>>2) - (LINES&1); i++)); {
    printf "\x9B%s" A M B 2L A
    nap 0.02
  }
}

curs_store() {
  local -n ref=$1
  local IFS='[;'
  read -rs -d R -p $'\x9B6n' _ ref[0] ref[1] _
}

curs_load() {
  local -n ref=${1}
  printf "\x9B${ref[0]};${ref[1]}H"
  printf "\x1B7"
}

exit_sequence() {
  local exit_query='Abort setup process'
  local exit_opts=('(Y|y)es' '(N|n)o')
  local -a curs
  curs_store curs && display_cleave
  # Center cursor
  printf "\x9B$((TRANSVERSE-(LINES&1)));${SAGITTAL}H"
  # Pad strings if columns are odd
  ((COLUMNS&1)) && exit_query+=' ' && exit_opts[0]+=' '
  # Finalise query and concatenate option strings
  exit_query+='?' && exit_opts="${exit_opts[0]}   ${exit_opts[1]}"
  # Center and print query and option strings based on length
  printf "\x9B$(((${#exit_query}>>1)-!(COLUMNS&1)))D${exit_query}"
  printf "\x9B${SAGITTAL}G\x9B2B"
  printf "\x9B$(((${#exit_opts}>>1)-!(COLUMNS&1)))D${exit_opts}"
  # Infinite loop for confirmation
  for((;;)); {
    read "${TTIN_OPTS[@]}" -N1
    # Continue loop if timed out
    (($?>128)) && continue
    case "${REPLY}" in
      Y|y) exit 0;;
      N|n) break;;
      *) continue;;
    esac
  }
  display_init
  curs_load curs
}

kb_nav() {
  local key
  # Infinite loop
  for ((;;)); {
    read "${TTIN_OPTS[@]}" -N1 key
    # Continue loop if read times out from lack of input
    (($?>128)) && continue
    # Handling escape characters
    [[ ${key} == $'\x1B' ]] && {
      read "${TTIN_OPTS[@]}" -N1
      # Handling CSI (Control Sequence Introducer) sequences ('[' + sequence)
      [[ "${REPLY}" != "[" ]] && return 0 || read "${TTIN_OPTS[@]}" -N2
      key=$'\x9B'${REPLY}
    }
    case ${key} in
      # UP
      k|$'\x9BA') printf "\x9BuUP";;
      # DOWN
      j|$'\x9BB') printf "\x9BuDOWN";;
      # RIGHT
      l|$'\x9BC') printf "\x9BuRIGHT";;
      # LEFT
      h|$'\x9BD') printf "\x9BuLEFT";;
      # HOME
      '1~') ((str_idx)) && printf "\x9B${str_idx}D" && str_idx=0;;
      # END
      '4~')
        ((str_idx < ${#str})) && {
          printf "\x9B$(( ${#str} - str_idx ))C"
          str_idx=${#str}
        }
      ;;
      # pg up
      $'\x02'|$'\x9B5~') printf "\x9BuPgUP";;
      # pg down
      $'\x06'|$'\x9B6~') printf "\x9BuPgDOWN";;
      # Do nothing
      *) :;;
    esac
  }
}

kb_search() {
  local -i str_idx=0
  local str=""
  case "${REPLY}" in
    # UP
    A) printf "\x9BuUP";;
    # DOWN
    B) printf "\x9BuDOWN";;
    # RIGHT
    C) ((str_idx < ${#str})) && ((str_idx++)) && printf "\x9BC";;
    # LEFT
    D) ((str_idx)) && ((str_idx--)) && printf '\x08';;
    # HOME
    '1~') ((str_idx)) && printf "\x9B${str_idx}D" && str_idx=0;;
    # DEL
    '3~')
      # If in middle of string 
      ((str_idx != ${#str})) && {
        # Print string tail if any, erase trailing char, and reset cursor
        printf '%s' ${str:$((str_idx + 1))}
        printf '%b' "\x20" "\x9B$(( ${#str} - str_idx ))D"
        str=${str:0:${str_idx}}"${str:$((str_idx + 1))}"
      }
    ;;
    # END
    '4~')
      ((str_idx < ${#str})) && {
        printf "\x9B$(( ${#str} - str_idx ))C"
        str_idx=${#str}
      }
    ;;
    # pg up
    '5~') printf "\x9BuPgUP";;
    # pg down
    '6~') printf "\x9BuPgDOWN";;
    # Do nothing
    *) :;;
  esac
  case "${REPLY}" in
    $'\x7F'|$'\x08')
      # If index more than 0, print ANSI backspace (i.e. move cursor left)
      ((str_idx)) && {
        printf "\x08"
        # If at last index, do a simple trim and space+backspace
        ((str_idx == ${#str})) && str=${str:0:-1} && printf "\x20\x08" || {
          # Else print string tail, and erase trailing char with CSI instead
          # of whitespace (unlike when handling DEL key above) which allows
          # convenient re-use of arithmetic syntax when repositioning cursor
          printf '%s' ${str:${str_idx}}
          printf "\x9B%s" X "$((${#str} - str_idx))D"
          str=${str:0:$((str_idx - 1))}"${str:${str_idx}}"
        }
        ((str_idx--))
      }
    ;;
    $'\x0D') echo "ent";; # stty set to icrnl; ENTER=Linefeed/newline
    $'\x0E') printf "\x0F";; # Prevent activation of G1 translation table
    $'\x07'|$'\x09'|$'\x18'|$'\x1A') :;; # Ignore other C0 control codes
    *) printf "${REPLY}" && str=$str"${REPLY}" && ((str_idx++));;
  esac
}

keymap_handler() {
  local keymaps=($(localectl list-keymaps))
  local -a curs
  curs_store curs
  win_draw 2 $SAGITTAL $((LINES-2)) $((SAGITTAL-1))
  kb_nav
  #printf "%s" ${keymaps[@]}
  curs_load curs
}

main() {
  trap 'display_clean' EXIT
  trap 'get_con_size; win_draw' SIGWINCH
  trap 'exit_sequence' SIGINT
  [[ $1 == -d ]] && test_size || set_con
  display_init
  keymap_handler
  exit_sequence
}
main "$@"
