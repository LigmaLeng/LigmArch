#!/usr/bin/env bash
#
# TODO: Write file header

[[ ${0%/*} == ${0} ]] && CTX_DIR='.' || CTX_DIR=${0%/*}
CACHE_DIR=${XDG_CACHE_HOME:=${HOME}/.cache/ligmarch.conf}
TEMPLATE_DIR="${CTX_DIR}/options.conf"
READ_OPTS=(-rs -t 0.05)
readonly CTX_DIR CACHE_DIR TEMPLATE_DIR READ_OPTS
declare -i LINES COLUMNS TRANSVERSE SAGITTAL
declare -a SETOPT_KEYS SETOPT_KEYS_F
declare -a KEYMAP MIRRORS LOCALES
declare -a setopt_pairs_f win_ctx_a
declare -A setopt_pairs win_ctx
win_ctx=(y '' x '' m '' n '' nref '' offset '' idx '')

die() {
  local -a bash_trace=(${BASH_SOURCE[1]} ${BASH_LINENO[0]} ${FUNCNAME[1]})
  printf '\x9B%s' m 2J r
  printf '%s: line %d: %s: %s\n' ${bash_trace[@]} "${1-Died}" >&2
  printf 'press any key to continue'
  for((;;)){ read ${READ_OPTS[@]} -N1; (($?>128)) || exit 1;}
}

echoes()for((i=0;i++<$2;)){ printf $1;}

nap() {
  # Open file descriptor if doesn't exist pipe empty subshell
  [[ -n "${nap_fd:-}" ]] || { exec {nap_fd}<> <(:);}
  # Attempt to read from empty file descriptor indefinitely if no timeout given
  read -t ${1:-0.001} -u $nap_fd || :
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
  ((TRANSVERSE=(LINES+1)>>1,SAGITTAL=(COLUMNS+1)>>1))
}

test_size() {
  # Temp vars as invoking stty overrides values for LINES and COLUMNS
  local -a dim
  OPT_TEST=1
  read -ra dim -p 'Enter display size in {LINES} {COLUMNS} (ex: 25 80): '
  set_console
  !((${dim[0]})) || !((${dim[1]})) && die 'Parse Error'
  LINES=${dim[0]}; COLUMNS=${dim[1]}
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
  local fissure
  fissure=$(echoes '\xC4' $((COLUMNS-2)))
  # Cursor on transverse plane
  printf '\x9B%s;H' $TRANSVERSE
  # Grow fissure from from saggital plane laterally along transverse plane
  for((i=0;i<SAGITTAL-1;i++)){
    printf '\x9B%sG\xCD' $((SAGITTAL-i)) $((SAGITTAL+i+!(COLUMNS&1)))
    nap 0.003
  }
  # Ligate fissure
  echoes '\xCE\x0D' 2 
  nap 0.1
  # Pilot cleavage and swap ligatures
  printf '\xD0%b' $fissure '\n'
  printf '\xD2%b' $fissure '\x9BA\x0D'
  # Widen pilot cleave if lines are odd
  # A M B L: up  delete_line  down  insert_line
  ((LINES&1)) && printf '\x9B%s' A M B L A
  # Continue widening
  for((i=0;i<(TRANSVERSE>>2)-(LINES&1);i++)){
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
  printf '\x9B%s;%sH\x1B7' ${ref[0]} ${ref[1]}
}

get_line() {
  local -i curs
  IFS='[;' read -rs -d R -p $'\x9B6n' _ curs _
  printf $curs
}

print_pg() {
  local -i i y x m n len lim
  local -n w ref
  local white_sp
  w=win_ctx ref=${win_ctx[nref]}
  y=w[y] x=w[x] m=w[m]-2 n=w[n]-2 len=${#ref[@]}
  ((lim=w[offset]+m<len?w[offset]+m:len))
  white_sp=$(echoes '\x20' $n)
  # Return cursor to page origin
  printf '\x9B%s;%sH' $((y+1)) $((x+1))
  # Erasing whole window is simpler as default virtual console doesn't store
  # scrolling input and scrolling messes up page borders
  for((i=0;i++<m;)){ printf '\x1B7%s\x1B8\x9BB' "${white_sp}";}
  printf '\x9B%s;%sH' $((y+1)) $((x+1))
  # Populate page
  for((i=w[offset]-1;++i<lim;)){ printf '\x1B7  %s\x1B8\x9BB' "${ref[$i]}";}
  # Move cursor up to selection and print highlighted selection
  printf '\x9B%sA\x1B7  \x9B7m%s\x1B8' $((i-=w[idx])) "${ref[$((lim-i))]}"
  # Don't print cursor indicator if argument provided
  [[ "${1:-}" == 'nocurs' ]] || printf '\xAF\x9BD'
}

win_ctx_op(){
  local -n w wa
  w=win_ctx wa=win_ctx_a
  case $1 in
    'set')
      read -d '' w[y] w[x] w[m] w[n] w[nref] <<< "${2//,/ }"
      w[offset]=0 w[idx]=0
    ;;
    'push')
      : "${w[y]},${w[x]},${w[m]},${w[n]},${w[nref]},${w[offset]},${w[idx]}"
      win_ctx_a+=("$_")
    ;;
    'pop')
      # Inner dimensions
      for i in ${wa[@]};{
        read -d '' w[y] w[x] w[m] w[n] w[nref] w[offset] w[idx] <<< "${i//,/ }"
        draw_window
        print_pg 'nocurs'
      }
      # Print cursor indicator for top window context
      printf '\xAF\x9BD'
      unset win_ctx_a[-1]
  esac
}

exit_prompt() {
  local exit_query exit_opts
  [[ ${FUNCNAME[1]} == 'exit_prompt' ]] && return
  exit_query='Abort setup process' exit_opts=('(Y|y)es' '(N|n)o')
  win_ctx_op 'push'
  display_cleave
  # Center cursor
  printf '\x9B%s;%sH' $((TRANSVERSE-(LINES&1))) $SAGITTAL
  # Pad strings if columns are odd
  ((COLUMNS&1)) && { exit_query+=' '; exit_opts[0]+=' ';}
  # Finalise query and concatenate option strings
  exit_query+='?' exit_opts="${exit_opts[0]}   ${exit_opts[1]}"
  # Center and print query and option strings based on length
  printf '\x9B%sD%s' $(((${#exit_query}>>1)-!(COLUMNS&1))) "$exit_query"
  printf '\x9B%s' ${SAGITTAL}G 2B
  printf '\x9B%sD%s' $(((${#exit_opts}>>1)-!(COLUMNS&1))) "$exit_opts"
  # Infinite loop for confirmation
  for((;;)){
    read ${READ_OPTS[@]} -N1
    # Continue loop if timed out
    (($?>128)) && continue
    case "$REPLY" in
      Y|y) exit 0;;
      N|n) break;;
    esac
  }
  win_ctx_op 'pop'
}

parse_files() {
  local lim
  lim=0
  # Parse config template file
  while read; do
    case $REPLY in
      # Section header
      '['*)
        # Trim brackets
        : "${REPLY#[}"
        SETOPT_KEYS+=("${_%]}")
        # Keep track of longest optkey
        ((lim=${#SETOPT_KEYS[-1]}>lim?${#SETOPT_KEYS[-1]}:$lim))
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
  # Format spacing for printing setup options
  for i in ${SETOPT_KEYS[@]};{
    SETOPT_KEYS_F+=("${i/_/ }$(echoes '\x20' $((lim-${#i}+3)))")
  }
  # Retrieve currently active mirrors
  [[ -a "/etc/pacman.d/mirrorlist" ]]
  exec {mirror_fd}<> <(curl -s "https://archlinux.org/mirrorlist/all/https/")
  while read -u $mirror_fd; do [[ "$REPLY" == '## Worldwide' ]] && break; done
  while read -t 0 -u $mirror_fd && read -u $mirror_fd; do
    [[ "$REPLY" == '## '* ]] && MIRRORS+=("${REPLY#* }")
  done
  # Get kbd keymap files
  KEYMAP=($(localectl list-keymaps))
  # Parse supported locales and format spacing for printing
  lim=$((SAGITTAL-4))
  while read; do
    LOCALES+=("${REPLY% *}$(echoes '\x20' $((lim-${#REPLY})))${REPLY#* }")
  done < "/usr/share/i18n/SUPPORTED"
  declare -r SETOPT_KEYS SETOPT_KEYS_F KEYMAP LOCALES
}

draw_window() {
  local -i y x m n offset
  local -n w
  local horz vert
  w=win_ctx y=w[y] x=w[x] m=w[m] n=w[n] offset=0
  horz=$(echoes '\xCD' $((n - 2))) vert="\xBA\x9B$((n-2))C\xBA"
  # Cursor origin and print top border
  printf '\x9B%s;%sH\xC9%s\xBB' $y $x $horz
  # Print vertical borders on every line but first and last
  for((;offset++<m-2;)){ printf '\x9B%s;%sH%b' $((y+offset)) $x $vert;}
  # Print bottom border
  printf '\x9B%s;%sH\xC8%s\xBC' $((y+m-1)) $x $horz
  # Bound scrolling region, bring cursor into window, save cursor state
  printf '\x9B%s;%sr\x9B%s;%sH\x1B7' $((y+1)) $((y+m-2)) $((y+1)) $((x+1))
}

draw_main() {
  win_ctx_op 'set' "1,1,${LINES},${COLUMNS},setopt_pairs_f"
  draw_window
  for((i=0;i<${#SETOPT_KEYS[@]};i++)){
    setopt_pairs_f[$i]="${SETOPT_KEYS_F[$i]}${setopt_pairs[${SETOPT_KEYS[$i]}]}"
  }
  kb_nav
}

draw_select() {
  local -n ref
  local optkey
  optkey=${SETOPT_KEYS[$1]}
  win_ctx_op 'push'
  # Refer to corresponding array for each option key
  win_ctx_op 'set' "2,${SAGITTAL},$((LINES-2)),$((SAGITTAL-1)),${optkey}"
  draw_window
  kb_nav
  (($?)) || {
    ref=$optkey
    [[ "$optkey" == 'LOCALES' ]] && {
      : "${ref[${win_ctx[idx]}]}"
      setopt_pairs[$optkey]=${_%% *}
    } || setopt_pairs[$optkey]=${ref[${win_ctx[idx]}]}
    setopt_pairs_f[$1]="${SETOPT_KEYS_F[$1]}${setopt_pairs[$optkey]}"
  }
  win_ctx_op 'pop'
}

kb_nav() {
  local key
  local -i len pglim
  local -n ref idx arr_offs
  ref=${win_ctx[nref]} idx=win_ctx[idx] arr_offs=win_ctx[offset]
  len=${#ref[@]} pglim=win_ctx[m]-2
  print_pg
  for((;;)){
    read ${READ_OPTS[@]} -N1 key
    # Continue loop if read times out from lack of input
    (($?>128)) && continue
    # Handling escape characters
    [[ ${key} == $'\x1B' ]] && {
      read ${READ_OPTS[@]} -N1
      # Handling CSI (Control Sequence Introducer) sequences ('[' + sequence)
      [[ "${REPLY}" != "[" ]] && return 1 || read ${READ_OPTS[@]} -N2
      key=$'\x9B'${REPLY}
    }
    case ${key} in
      # UP
      k|$'\x9BA')
        # Ignore 0th index
        ((!idx)) && continue
        # If cursor on first line of page, decrement indices and print
        ((idx==arr_offs)) && { ((arr_offs--,idx--)); print_pg;} || {
        # Else remove highlight on current line before printing subsequent line
          printf '  %s\x1B8\x9BA\x1B7' "${ref[$((idx--))]}"
          printf '\xAF \x9B7m%s\x1B8' "${ref[$idx]}"
        }
      ;;
      # DOWN
      j|$'\x9BB')
        # Ignore last index
        ((idx+1==len)) && continue
        # If cursor on last line of page, increment indices and print
        ((idx+1==arr_offs+pglim)) && { ((arr_offs++,idx++)); print_pg;} || {
        # Else remove highlight on current line before printing subsequent line
          printf '  %s\x1B8\x9BB\x1B7' "${ref[$((idx++))]}"
          printf '\xAF \x9B7m%s\x1B8' "${ref[$idx]}"
        }
      ;;
      # ENTER
      $'\n') 
        printf '  \x9B7m%s\x1B8' "${ref[$idx]}"
        [[ "${win_ctx[nref]}" == 'setopt_pairs_f' ]] && {
          draw_select $idx
        } || return 0
      ;;
      # SPACE
      $'\x20') echo 'space';;
      # RIGHT
      l|$'\x9BC') printf "\x9BuRIGHT";;
      # LEFT
      h|$'\x9BD') printf "\x9BuLEFT";;
      # HOME
      $'\x9B1~') arr_offs=0; idx=0; print_pg;;
      # END
      $'\x9B4~') ((arr_offs=len>pglim?len-pglim:0,idx=len-1)); print_pg;;
      # PGUP
      $'\x9B5~')
        ((arr_offs=arr_offs-pglim>0?arr_offs-pglim:0))
        ((idx=idx-pglim>0?idx-pglim:0))
        print_pg
      ;;
      # PGDOWN
      $'\x9B6~')
        ((arr_offs+pglim<len-pglim)) && ((arr_offs+=pglim)) ||
          ((arr_offs=len>pglim?len-pglim:0))
        ((idx=idx+pglim<len?idx+pglim:len-1))
        print_pg
      ;;
    esac
  }
}

main() {
  trap 'reset_console' EXIT
  trap 'get_console_size; draw_window' SIGWINCH
  trap 'exit_prompt' SIGINT
  [[ $1 == -d ]] && test_size || set_console
  display_init
  parse_files
  draw_main
  nap 2
}
main "$@"
