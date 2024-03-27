#!/usr/bin/env bash
#
# TODO: Write file header

[[ ${0%/*} == ${0} ]] && readonly CTX_DIR='.' || readonly CTX_DIR=${0%/*}
readonly CACHE_DIR="${XDG_CACHE_HOME:=${HOME}/.cache/ligmarch.conf}"
readonly TEMPLATE_DIR="${CTX_DIR}/options.conf"
readonly READ_OPTS=(-rs -t 0.02)
declare -i LINES COLUMNS TRANSVERSE SAGITTAL
declare -a SETOPT_KEYS SETOPT_KEYS_F KEYMAP_A LOCALES_A
declare -a setopt_pairs_f win_ctx_a
declare -A setopt_pairs
declare -A win_ctx=(y '' x '' m '' n '' nref '' offset '' idx '')
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
  # Open file descriptor if doesn't exist pipe empty subshell
  [[ -n "${nap_fd:-}" ]] || { exec {nap_fd}<> <(:);}
  #[[ -n "${nap_fd:-}" ]] || { exec {nap_fd}<> <(:);} 2>/dev/null
  # Attempt to read from empty file descriptor indefinitely if no timeout given
  read -t "${1:-0.001}" -u $nap_fd || :
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
  IFS='[;' read -rs -d R -p $'\x9B6n' _ ref[0] ref[1] _
}

curs_load() {
  local -n ref=$1
  printf "\x9B${ref[0]};${ref[1]}H\x1B7"
}

get_line() {
  local -i curs
  IFS='[;' read -rs -d R -p $'\x9B6n' _ curs _
  printf $curs
}

win_ctx_op(){
  local -n w
  local -a arr
  case $1 in
    'set')
      w=win_ctx
      read -d '' w[y] w[x] w[m] w[n] w[nref] w[offset] w[idx] <<< "${2//,/ }"
    ;;
    'push')
      w=win_ctx
      : "${w[y]},${w[x]},${w[m]},${w[n]},${w[nref]},${w[offset]},${w[idx]}"
      win_ctx_a+=("$_")
    ;;
    'rebuild')
      w=win_ctx_a
      printf '\x9B%s' 2J r
      for ((i=0;i<${#w[@]};i++)); do
        read -d '' -a arr <<< "${w[$i]//,/ }"
        draw_window ${arr[0]} "${arr[1]};${arr[2]}"
      done
    #;&
    ;;
    'pop')
      unset win_ctx_a[-1]
    ;;
  esac
}

exit_prompt() {
  [[ ${FUNCNAME[1]} == 'exit_prompt' ]] && return
  local exit_query='Abort setup process'
  local exit_opts=('(Y|y)es' '(N|n)o')
  local -a curs
  win_ctx_op 'push'
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
  win_ctx_op 'rebuild'
  #printf '%s %s\n' ${win_ctx_test[@]@k}
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
        SETOPT_KEYS+=("${_%]}")
        # Keep track of longest optkey
        ((optsp=${#SETOPT_KEYS[-1]}>optsp?${#SETOPT_KEYS[-1]}:$optsp))
      ;;
      value*)
        setopt_pairs[${SETOPT_KEYS[-1]}]=${REPLY#*= }
      ;;
      list*)
        read setopt_pairs[${SETOPT_KEYS[-1]}]
        while read; do
          [[ -z $REPLY ]] && break || {
            setopt_pairs[${SETOPT_KEYS[-1]}]+=" ${REPLY//[[:space:]]}"
          }
        done
      ;;
    esac
  done < "$TEMPLATE_DIR"
  # Format optkey spacing for prints
  for i in ${SETOPT_KEYS[@]}; do
    SETOPT_KEYS_F+=("${i/_/ }$(echoes '\x20' $((optsp-${#i}+3)))")
  done
  # Get kbd keymap files and parse supported locales
  KEYMAP_A=($(localectl list-keymaps))
  while read; do
    LOCALES_A+=("$REPLY")
  done < "/usr/share/i18n/SUPPORTED"
  declare -r SETOPT_KEYS SETOPT_KEYS_F KEYMAP_A LOCALES_A
}

draw_window() {
  local -n w=win_ctx
  local -i offset=0
  local horz=$(echoes '\xCD' $((w[n] - 2)))
  local vert="\xBA\x9B$((w[n]-2))C\xBA"
  #       Cursor origin and print top border
  printf "\x9B${w[y]};${w[x]}H\xC9${horz}\xBB"
  #       Print vertical borders on every line but first and last
  for((;offset++<w[m]-2;)){ printf "\x9B$((w[y]+offset));${w[x]}H${vert}";}
  #       Print bottom border
  printf "\x9B$((w[y]+w[m]-1));${w[x]}H\xC8${horz}\xBC"
  #       Bound scrolling region, bring cursor into window
  printf "\x9B$((w[y]+1));%s" $((w[y]+w[m]-2))r $((w[x]+1))H
  #       Save cursor state
  printf '\x1B7'
}

draw_main() {
  win_ctx_op 'set' "1,1,${LINES},${COLUMNS},setopt_pairs_f,0,0"
  draw_window
  for ((i=0;i<${#SETOPT_KEYS[@]};i++)); do
    setopt_pairs_f[$i]="${SETOPT_KEYS_F[$i]}${setopt_pairs[${SETOPT_KEYS[$i]}]}"
  done
  kb_nav setopt_pairs_f $((LINES-2)) $((COLUMNS-2))
}

draw_select() {
  local -i optkey_idx=$1
  win_ctx_op 'push'
  : "2,${SAGITTAL},$((LINES-2)),$((SAGITTAL-1)),${SETOPT_KEYS[$1]}_A,0,0"
  win_ctx_op 'set' "2,${SAGITTAL},$((LINES-2)),$((SAGITTAL-1)),setopt_pairs_f,0,0"
  draw_window
  kb_nav $((LINES-4)) $((SAGITTAL-3))
}

kb_nav() {
  local key
  local -n ref=$1
  local -ir dim_y=$2
  local -ir dim_x=$3
  local -ir lim_y_lo=$(((LINES-dim_y>>1)+1))
  local -ir lim_y_hi=$((lim_y_lo+dim_y-1))
  local -ir len=${#ref[@]}
  local -n idx=win_ctx[idx]
  local -r white_sp=$(echoes '\x20' $dim_x)
  local -a curs
  curs_store curs
  printf '\xAF \x9B7m%s\x1B8\x9BB' "${ref[$idx]}"
  for ((i=0;++i<len;)); do
    ((i==dim_y)) && break
    printf "\x1B7  ${ref[$i]}\x1B8\x9BB"
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
        # If non-zero index
        ((idx)) && {
          # If cursor on first line of window
          (($(get_line)==lim_y_lo)) && {
            # Erasing whole window is easier without relative index references
            # and default virtual console doesn't store scrolling input anyways
            curs_load curs
            for ((i=0;i++<dim_y;));{ printf "${white_sp}\x1B8\x9BB\x1B7";}
            curs_load curs
            # Print highlighted selection on first line
            printf '\xAF \x9B7m%s\x1B8\x9BB' "${ref[$((--idx))]}"
            # Print remaining lines
            for ((i=0;++i<dim_y;)); do
              printf '\x1B7  %s\x1B8\x9BB' "${ref[$((idx+i))]}"
            done
            curs_load curs
          } || {
          # Else remove highlight on current selection before printing next
            printf '  %s\x1B8\x9BA\x1B7' "${ref[$((idx--))]}"
            printf '\xAF \x9B7m%s\x1B8' "${ref[$idx]}"
          }
        }
      ;;
      # DOWN
      j|$'\x9BB')
        # If index less than total elements
        ((idx+1<len)) && {
          # If cursor on last line of window
          (($(get_line)==lim_y_hi)) && {
            # Erasing window
            curs_load curs
            for ((i=0;i++<dim_y;));{ printf "${white_sp}\x1B8\x9BB\x1B7";}
            curs_load curs
            # Print preceding lines
            for ((i=idx-dim_y+2;i<idx+1;i++)); do
              printf '\x1B7  %s\x1B8\x9BB' "${ref[$i]}"
            done
            # Print highlighted selection on last line
            printf '\x1B7\xAF \x9B7m%s\x1B8' "${ref[$((++idx))]}"
          } || {
          # Else remove highlight on current selection before printing next
            printf '  %s\x1B8\x9BB\x1B7' "${ref[$((idx++))]}"
            printf '\xAF \x9B7m%s\x1B8' "${ref[$idx]}"
          }
        }
      ;;
      # ENTER
      $'\n') 
        printf '  \x9B7m%s\x1B8\x1B7' "${ref[$idx]}"
        draw_select $idx
      ;;
      # SPACE
      $'\x20') echo 'space';;
      # RIGHT
      l|$'\x9BC') printf "\x9BuRIGHT";;
      # LEFT
      h|$'\x9BD') printf "\x9BuLEFT";;
      # HOME | END | PGUP | PGDOWN
      $'\x9B1~'|$'\x9B4~'|$'\x9B5~'|$'\x9B6~') 
        # Erasing window
        curs_load curs
        for ((i=0;i++<dim_y;));{ printf "${white_sp}\x1B8\x9BB\x1B7";}
        curs_load curs
        case ${key} in
          $'\x9B1~') # HOME
            # Reprint options similar to when entering function
            printf '\xAF \x9B7m%s\x1B8\x9BB' "${ref[$((idx=0))]}"
            for ((i=idx;++i<len;)); do
              ((i==dim_y)) && break
              printf "\x1B7  ${ref[$i]}\x1B8\x9BB"
            done && curs_load curs
          ;;
          $'\x9B4~') # END
            ((len>dim_y)) && ((idx=len-dim_y-1)) || ((idx=-1))
            for ((idx;++idx<len;)); do
              (($(get_line)>lim_y_hi)) && break
              printf "\x1B7  ${ref[$idx]}\x1B8\x9BB"
            done
            printf '\x1B8\xAF \x9B7m%s\x1B8' "${ref[$((--idx))]}"
          ;;
          $'\x9B5~') # PGUP
            # If scroll margins are within first page
            # Reprint options similar to when entering function
            ((idx<dim_y+1)) && {
              printf '\xAF \x9B7m%s\x1B8\x9BB' "${ref[$((idx=0))]}"
              for ((i=idx;++i<len;)); do
                ((i==dim_y)) && break
                printf "\x1B7  ${ref[$i]}\x1B8\x9BB"
              done && curs_load curs
            } || {
            # Else print from offset onward
              ((idx-=dim_y))
              printf '\xAF \x9B7m%s\x1B8\x9BB' "${ref[$idx]}"
              for ((i=0;++i<dim_y;)); do
                printf "\x1B7  ${ref[$((idx+i))]}\x1B8\x9BB"
              done && curs_load curs
            }
          ;;
          $'\x9B6~') # PGDOWN
            # If scroll margins are within last page
            # Reprint options similar to when END key is pressed
            ((idx>len-dim_y-2)) && {
              ((len>dim_y)) && ((idx=len-dim_y-1)) || ((idx=-1))
              for ((idx;++idx<len;)); do
                (($(get_line)>lim_y_hi)) && break
                printf "\x1B7  ${ref[$idx]}\x1B8\x9BB"
              done
              printf '\x1B8\xAF \x9B7m%s\x1B8' "${ref[$((--idx))]}"
            } || {
            # Else print add offset and print to sum
              ((idx+=dim_y))
              for ((i=dim_y;--i>0;)); do
                printf "\x1B7  ${ref[$((idx-i))]}\x1B8\x9BB"
              done && printf '\x1B7\xAF \x9B7m%s\x1B8' "${ref[$idx]}"
            }
          ;;
        esac
      ;;
    esac
  }
}

main() {
  trap 'reset_console' EXIT
  #trap 'get_console_size; draw_window' SIGWINCH
  trap 'exit_prompt' SIGINT
  [[ $1 == -d ]] && test_size || set_console
  parse_files
  display_init
  draw_main
  nap 2
}
main "$@"
