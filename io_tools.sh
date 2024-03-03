#!/usr/bin/env bash
#
# TODO: Write file header

[[ ${0%/*} == ${0} ]] && readonly CTX_DIR='.' || readonly CTX_DIR=${0%/*}
readonly CACHE_DIR="${XDG_CACHE_HOME:=${HOME}/.cache/ligmarch.conf}"
readonly TEMPLATE_DIR="${CTX_DIR}/options.conf"
readonly READ_OPTS=(-rs -t 0.02)
declare -i LINES COLUMNS TRANSVERSE SAGITTAL
declare -a SETUP_OPTKEYS setup_opts_f KEYMAP_FILES SUPPORTED_LOCALES
declare -A setup_opts user_opts
# https://archlinux.org/mirrorlist/all/https/
# bootloader?
# use swap?
# audio
# AUR

die() {
  local -a bash_trace=(${BASH_SOURCE[1]} ${BASH_LINENO[0]} ${FUNCNAME[1]})
  printf '\x9B%s' m 2J r
  printf '%s: line %d: %s: %s\n' ${bash_trace[@]} "${1-Died}" >&2
  printf 'press any key to continue'
  for((;;)){ read "${READ_OPTS[@]}" -N1; (($?>128)) || exit 1;}
}

echoes()for((i=0;i++<$2;)){ printf $1;}

nap() {
  local IFS
  # Open file descriptor if doesn't exist pipe empty subshell
  [[ -n "${nap_fd:-}" ]] || { exec {nap_fd}<> <(:);} 2>/dev/null
  # Attempt to read from empty file descriptor indefinitely if no timeout given
  read ${1:+-t "$1"} -u $nap_fd || :
}

set_console() {
  readonly LC_ALL=C
  # Backup and modify stty settings for io operations (restored on exit)
  readonly STTY_BAK=$(stty -g)
  stty -echo -icanon -ixon icrnl isig susp undef
  # Select default (single byte character set) and lock G0 and G1 charsets
  printf '\x1B%s' '%@' '(K' ')K'
}

reset_console() {
  # m     Reset Colours 
  # ?25h  Show cursor
  # ?7h   Disable line wrapping
  # 2J    Clear screen
  # r     Reset scrolling region
  printf '\x9B%s' m ?25h ?7h 2J r
  # Return character set back to UTF-8
  printf '\x1B%%G'
  # Reset stty if modified
  [[ -n $STTY_BAK ]] && stty $STTY_BAK
}

get_console_size() {
  ((OPT_TEST)) || read -r LINES COLUMNS < <(stty size)
  TRANSVERSE=$(((LINES+1)>>1))
  SAGITTAL=$(((COLUMNS+1)>>1))
}

test_size() {
  # Temp vars as invoking stty overrides values for LINES and COLUMNS
  local -a dim
  OPT_TEST=1
  read -ra dim -p 'Enter display size in {LINES} {COLUMNS} (ex: 25 80): '
  set_console
  (( ${#dim[@]} )) || return 0
  !(( ${dim[0]} )) || !(( ${dim[1]} )) && die 'Parse Error'
  LINES=${dim[0]}
  COLUMNS=${dim[1]}
  return 0
}

parse_files() {
  local -i optsp=0
  # Parse config template file
  while read; do
    case $REPLY in
      # Section header
      '['*)
        # Trim brackets
        : "${REPLY#[}"
        SETUP_OPTKEYS+=("${_%]}")
        # Keep track of longest optkey
        ((optsp=${#SETUP_OPTKEYS[-1]}>optsp?${#SETUP_OPTKEYS[-1]}:$optsp))
      ;;
      value*)
        setup_opts[${SETUP_OPTKEYS[-1]}]=${REPLY#*= }
      ;;
      list*)
        read setup_opts[${SETUP_OPTKEYS[-1]}]
        while read; do
          [[ -z $REPLY ]] && break || {
            setup_opts[${SETUP_OPTKEYS[-1]}]+=" ${REPLY//[[:space:]]}"
          }
        done
      ;;
    esac
  done < "$TEMPLATE_DIR"
  # Format optkey spacing for prints
  for i in ${SETUP_OPTKEYS[@]}; do
    setup_opts_f+=("${i/_/ }$(echoes '\x20' $((optsp-${#i}+3)))")
  done
  # Get kbd keymap files and parse supported locales
  KEYMAP_FILES=($(localectl list-keymaps))
  while read; do
    SUPPORTED_LOCALES+=("$REPLY")
  done < "/usr/share/i18n/SUPPORTED"
}

draw_window() {
  local -i idx_y=${1:-1}
  local -i idx_x=${2:-1}
  local -i m=${3:-$LINES}
  local -i n=${4:-$COLUMNS}
  local -i offset=0
  local horz=$(echoes '\xCD' $((n - 2)))
  local vert="\xBA\x9B$((n-2))C\xBA"
  #       Cursor origin and print top border
  printf "\x9B${idx_y};${idx_x}H\xC9${horz}\xBB"
  #       Print vertical borders on every line but first and last
  for((;offset++<m-2;)){ printf "\x9B$((idx_y+offset));${idx_x}H${vert}";}
  #       Print bottom border
  printf "\x9B$((idx_y+m-1));${idx_x}H\xC8${horz}\xBC"
  #       Bound scrolling region, bring cursor into window
  printf "\x9B$((idx_y+1));%s" $((idx_y+m-2))r $((idx_x+1))H
  #       Save cursor state
  printf '\x1B7'
}

draw_menu() {
  draw_window
  for ((i=0;i<${#SETUP_OPTKEYS[@]};i++)); do
    setup_opts_f[$i]="${setup_opts_f[$i]}${setup_opts[${SETUP_OPTKEYS[$i]}]}"
  done
  kb_nav setup_opts_f $((LINES-2))
}

draw_select() {
  local -i optkey_idx=$1
  local -a curs
  curs_store curs
  draw_window 2 $SAGITTAL $((LINES-2)) $((SAGITTAL-1))
  case ${optkey_idx} in
    0) : "KEYMAP_FILES";;
    2) : "SUPPORTED_LOCALES";;
  esac
  kb_nav $_ $((LINES-4))
  curs_load curs
}

display_init() {
  get_console_size
  # 2J    Clear screen
  # 31m   Foreground red
  # ?25l  Hide cursor
  # ?7l   Disable line wrapping
  printf '\x9B%s' 2J 31m ?25l ?7l
}

display_cleave() {
  local fissure=$(echoes '\xC4' $((COLUMNS-2)))
  # Cursor on transverse plane
  printf "\x9B${TRANSVERSE};H"
  # Grow fissure from from saggital plane laterally along transverse plane
  for ((i=0; i < SAGITTAL-1; i++)); {
    printf "\x9B$(( SAGITTAL - i))G\xCD"
    printf "\x9B$(( SAGITTAL + i + !(COLUMNS&1) ))G\xCD"
    nap 0.003
  }
  # Ligate fissure
  echoes '\xCE\x0D' 2 && nap 0.1
  # Pilot cleavage and swap ligatures
  printf '\xD0%b' ${fissure} '\n'
  printf '\xD2%b' ${fissure} '\x9BA\x0D'
  # Widen pilot cleave if lines are odd
  # A M B L: up  delete_line  down  insert_line
  ((LINES&1)) && printf '\x9B%s' A M B L A
  # Continue widening
  for ((i=0; i < (TRANSVERSE>>2) - (LINES&1); i++)); {
    printf '\x9B%s' A M B 2L A
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
  printf '\x1B7'
}

exit_prompt() {
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
  printf '\x9B%s' ${SAGITTAL}G 2B
  printf "\x9B$(((${#exit_opts}>>1)-!(COLUMNS&1)))D${exit_opts}"
  # Infinite loop for confirmation
  for((;;)); {
    read "${READ_OPTS[@]}" -N1
    # Continue loop if timed out
    (($?>128)) && continue
    case "$REPLY" in
      Y|y) exit 0;;
      N|n) break;;
      *) continue;;
    esac
  }
  display_init && curs_load curs
}

kb_nav() {
  local key
  local -n ref=$1
  local -i row=0
  local -ir rows=${#ref[@]}
  local -ir lim=$2
  local -a curs
  curs_store curs
  printf ' \xAF \x9B7m%s\x1B8\x9BB' "${ref[$row]}"
  for ((i=1;i<rows;i++)); do
    ((i==lim)) && break
    printf "\x1B7   ${ref[$i]}\x1B8\x9BB"
  done
  curs_load curs
  for ((;;)); {
    read "${READ_OPTS[@]}" -N1 key
    # Continue loop if read times out from lack of input
    (($?>128)) && continue
    # Handling escape characters
    [[ ${key} == $'\x1B' ]] && {
      read "${READ_OPTS[@]}" -N1
      # Handling CSI (Control Sequence Introducer) sequences ('[' + sequence)
      [[ "${REPLY}" != "[" ]] && return 0 || read "${READ_OPTS[@]}" -N2
      key=$'\x9B'${REPLY}
    }
    case ${key} in
      # UP
      k|$'\x9BA')
        ((row)) && {
          printf '   %s\x1B8\x9BA\x1B7' "${ref[$((row--))]}"
          printf ' \xAF \x9B7m%s\x1B8\x1B7' "${ref[$row]}"
        }
      ;;
      # DOWN
      j|$'\x9BB')
        ((row+1<rows)) && ((row+1<lim)) && {
          printf '   %s\x1B8\x9BB\x1B7' "${ref[$((row++))]}"
          printf ' \xAF \x9B7m%s\x1B8\x1B7' "${ref[$row]}"
        }
      ;;
      $'\n') 
        printf '   \x9B7m%s\x1B8\x1B7' "${ref[$row]}"
        draw_select $row
      ;;
      $'\x20') echo 'space';;
      # RIGHT
      l|$'\x9BC') printf "\x9BuRIGHT";;
      # LEFT
      h|$'\x9BD') printf "\x9BuLEFT";;
      # HOME
      #'1~') ((str_idx)) && printf "\x9B${str_idx}D" && str_idx=0;;
      # END
      #'4~')
        #((str_idx < ${#str})) && {
          #printf "\x9B$(( ${#str} - str_idx ))C"
          #str_idx=${#str}
        #}
      #;;
      # pg up
      #$'\x02'|$'\x9B5~') printf "\x9BuPgUP";;
      # pg down
      #$'\x06'|$'\x9B6~') printf "\x9BuPgDOWN";;
    esac
  }
}

keymap_handler() {
  printf '%s\n' "${KEYMAP_FILES[@]}"
  local -a curs
  #curs_store curs
  #draw_window 2 $SAGITTAL $((LINES-2)) $((SAGITTAL-1))
  #kb_nav
  #printf "%s" ${keymaps[@]}
  #curs_load curs
}

locale_handler() {
  for ((i=0;i++<${#SUPPORTED_LOCALES[@]};)); do
    printf '%s\n' "${SUPPORTED_LOCALES[$i]}"
  done
}

main() {
  trap 'reset_console' EXIT
  trap 'get_console_size; draw_window' SIGWINCH
  trap 'exit_prompt' SIGINT
  [[ $1 == -d ]] && test_size || set_console
  parse_files
  display_init
  draw_menu
  nap 2
  #keymap_handler
  #exit_prompt
}
main "$@"
