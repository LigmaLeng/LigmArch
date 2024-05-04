#!/usr/bin/env bash
#
# TODO: Write file header

[[ ${0%/*} == ${0} ]] && CTX_DIR='.' || CTX_DIR=${0%/*}
CACHE_DIR=${XDG_CACHE_HOME:=${HOME}/.cache/ligmarch}
TEMPLATE_DIR="${CTX_DIR}/options.conf"
READ_OPTS=(-rs -t 0.03)
readonly CTX_DIR CACHE_DIR TEMPLATE_DIR READ_OPTS
declare -i LINES COLUMNS TRANSVERSE SAGITTAL
declare -a SETOPT_KEYS SETOPT_KEYS_F
declare -a KEYMAP LOCALE MIRRORS KERNEL EDITOR ADDITONAL_PACKAGES
declare -a setopt_pairs_f win_ctx_a
declare -A setopt_pairs win_ctx
win_ctx=(attr '' nref '' pg_type '' offset '' idx '' idxs '')

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

cleanup() {
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

print_pg() {
  local -i i y x m n len lim offs
  local -n w ref
  local white_sp
  w=win_ctx; ref=${w[nref]}; len=${#ref[@]}; offs=${w[offset]}
  read -d '' y x m n <<< "${w[attr]//,/ }"
  ((m-=2,n-=2)); ((lim=offs+m<len?offs+m:len))
  white_sp=$(echoes '\x20' $n)
  # Return cursor to page origin
  printf '\x9B%s;%sH' $((y+1)) $((x+1))
  # Erasing whole window is simpler as default virtual console doesn't store
  # scrolling input and scrolling messes up page borders
  for((i=0;i++<m;)){ printf '\x1B7%s\x1B8\x9BB' "${white_sp}";}
  printf '\x9B%s;%sH' $((y+1)) $((x+1))
  # Populate page
  case ${w[pg_type]} in
    'single')
      # If on main menu, truncate string if length would exceed available space
      # Else, iterate over list normally
      # Note: Both conditions contain similar statements to avoid the
      #       cost of evaluating unnecessary inner conditionals
      [[ ${w[nref]} == 'setopt_pairs_f' ]] && {
        for((i=offs-1;++i<lim;)){
          : "${ref[$i]}"; ((${#_}>COLUMNS-8)) && : "${_% *} ..."
          printf '\x1B7  %s\x1B8\x9BB' "$_"
        }
        printf '\x9B%sA\x1B7  ' $((i-=w[idx]))
        : "${ref[$((lim-i))]}"; ((${#_}>COLUMNS-8)) && : "${_% *} ..." || : "$_"
      } || {
        for((i=offs-1;++i<lim;)){ printf '\x1B7  %s\x1B8\x9BB' "${ref[$i]}";}
        printf '\x9B%sA\x1B7  ' $((i-=w[idx]))
        : "${ref[$((lim-i))]}"
      }
      # Move cursor up to selection and print highlighted selection
      printf '\x9B7m%s\x1B8' "$_"
    ;;
    'multi')
      for((i=offs-1;++i<lim;)){
        printf '\x1B7  < > %s\x1B8\x9BB' "${ref[$i]}"
      }
      printf '\x9B%s;%sH\x1B7' $y $((x+1))
      for i in ${w[idxs]//,/ };{
        ((i<offs||i>lim)) && continue
        printf '\x9B%sB  <\x04>\x1B8' $((i-offs+1))
      }
      i=${w[idx]}
      printf '\x9B%sB\x1B7\x9B6C\x9B7m%s\x1B8' $((i-offs+1)) "${ref[$i]}"
    ;;
  esac
  # Don't print cursor indicator if argument provided
  [[ "${1:-}" == 'nocurs' ]] || printf '\xAF\x9BD'
}

win_ctx_op(){
  local -n w wa
  local attr
  w=win_ctx wa=win_ctx_a
  case $1 in
    'set')
      read -d '' w[attr] w[nref] w[pg_type] <<< "${2//;/ }"
      w[offset]=0 w[idx]=0 w[idxs]=-1
    ;;
    'nav')
      case ${w[pg_type]} in
        'single') nav_single;;
        'multi') nav_multi;;
      esac
      return $?
    ;;
    'push')
      : "${w[attr]};${w[nref]};${w[pg_type]};${w[offset]};${w[idx]};${w[idxs]}"
      win_ctx_a+=("$_")
    ;;
    'pop')
      # Inner dimensions
      for i in ${wa[@]};{
        : "${i//;/ }"
        read -d '' w[attr] w[nref] w[pg_type] w[offset] w[idx] w[idxs] <<< "$_"
        draw_window
        print_pg 'nocurs'
      }
      # Print cursor indicator for top window context
      printf '\xAF\x9BD'
      unset wa[-1]
  esac
  return 0
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
  # Create cache directory if non-existent and parse config file
  [[ -d $CACHE_DIR ]] || mkdir -p $CACHE_DIR
  while read; do
    case $REPLY in
      # Brackets demarcate separate sections while parsing values that
      # correspond to the resulting header string after trimming '[' & ']'
      '['*)
        : "${REPLY#[}"
        SETOPT_KEYS+=("${_%]}")
        # Keep track of longest optkey for page formatting purposes
        ((lim=${#SETOPT_KEYS[-1]}>lim?${#SETOPT_KEYS[-1]}:$lim))
      ;;
      value*)
        setopt_pairs[${SETOPT_KEYS[-1]}]=${REPLY#*= }
      ;;
      list*)
        read setopt_pairs[${SETOPT_KEYS[-1]}]
        while read; do
          [[ -z $REPLY ]] && break || {
            setopt_pairs[${SETOPT_KEYS[-1]}]+="  ${REPLY//[[:space:]]}"
          }
        done
        [[ ${SETOPT_KEYS[-1]} =~ ^(KERNEL|EDITOR)$ ]] && {
          local key=${SETOPT_KEYS[-1]}
          local -n ref=$key
          ref=(${setopt_pairs[$key]})
          setopt_pairs[$key]=${ref[0]}
        }
      ;;
    esac
  done < "$TEMPLATE_DIR"
  # Format spacing for printing setup options
  for i in ${SETOPT_KEYS[@]};{
    SETOPT_KEYS_F+=("${i/_/ }$(echoes '\x20' $((lim-${#i}+3)))")
  }
  # Retrieve currently active mirrors from cache if available
  # Else, retrieve current mirrorlist from official mirrorlist generator page
  [[ -a "${CACHE_DIR}/mirrorlist" ]] && {
    while read; do MIRRORS+=("$REPLY"); done < "${CACHE_DIR}/mirror_countries"
  } || {
    exec {mirror_fd}<> <(curl -s "https://archlinux.org/mirrorlist/all/https/")
    # Discard lines up to first comment containing a named country
    while read -u $mirror_fd; do [[ "$REPLY" == '## Worldwide' ]] && break; done
    # Append countries with active mirrors to list while caching all server URLs
    while read -t 0 -u $mirror_fd && read -u $mirror_fd; do
      [[ "$REPLY" == '## '* ]] && {
        MIRRORS+=("${REPLY#* }")
        printf '%s\n' "${MIRRORS[-1]}" >> "${CACHE_DIR}/mirror_countries"
      }
      printf '%s\n' "$REPLY" >> "${CACHE_DIR}/mirrorlist"
    done
    exec {mirror_fd}>&-
  }
  # Get kbd keymap files
  KEYMAP=($(localectl list-keymaps))
  # Parse supported locales and format spacing for printing
  lim=$((SAGITTAL-4))
  while read; do
    LOCALE+=("${REPLY% *}$(echoes '\x20' $((lim-${#REPLY})))${REPLY#* }")
  done < "/usr/share/i18n/SUPPORTED"
  declare -r SETOPT_KEYS SETOPT_KEYS_F KEYMAP MIRRORS LOCALE
}

draw_window() {
  local -i y x m n offset
  local -n w
  local horz vert
  w=win_ctx offset=0
  read -d '' y x m n <<< "${w[attr]//,/ }"
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

seq_main() {
  win_ctx_op 'set' "1,1,${LINES},${COLUMNS};setopt_pairs_f;single"
  draw_window
  for((i=0;i<${#SETOPT_KEYS[@]};i++)){
    setopt_pairs_f[$i]="${SETOPT_KEYS_F[$i]}${setopt_pairs[${SETOPT_KEYS[$i]}]}"
  }
  win_ctx_op 'nav'
}

seq_select() {
  local -n w ref
  local optkey i
  optkey=${SETOPT_KEYS[$1]}
  win_ctx_op 'push'
  [[ $optkey =~ ^(MIRRORS|ADDITONAL_PACKAGES)$ ]] && : 'multi' || : 'single'
  # Refer to corresponding array for each option key
  win_ctx_op 'set' "2,${SAGITTAL},$((LINES-2)),$((SAGITTAL-1));${optkey};$_"
  w=win_ctx ref=$optkey
  [[ ${w[pg_type]} == 'multi' && "${setopt_pairs[$optkey]}" != 'unset' ]] && {
    for((i=-1;++i<${#ref[@]};)){
      [[ ${setopt_pairs[$optkey]## .*} =~ ${ref[$i]}\s? ]] && {
        setopt_pairs[$optkey]="${setopt_pairs[$optkey]/${BASH_REMATCH[0]}}"
        w[idxs]+=",$i"
      }
    }
    w[idxs]="${w[idxs]#-1,}"
  }
  draw_window
  win_ctx_op 'nav'
  ((!$?)) || {
    [[ ${w[pg_type]} == 'multi' ]] && {
      setopt_pairs[$optkey]=''
      [[ ${w[idxs]} == '-1' ]] && setopt_pairs[$optkey]='unset' || {
        while read; do
          setopt_pairs[$optkey]+="  ${ref[$REPLY]}"
        done < <(sort -n <<< "${w[idxs]//,/$'\n'}")
        setopt_pairs[$optkey]="${setopt_pairs[$optkey]#  }"
      }
    } || {
      # If selecting for LOCALE strip trailing string referring to the locales
      # corresponding character mapping as well as any remaining whitespace
      [[ $optkey == 'LOCALE' ]] && {
        : "${ref[${w[idx]}]}"; setopt_pairs[$optkey]=${_%% *}
      } || setopt_pairs[$optkey]=${ref[${w[idx]}]}
    }
    setopt_pairs_f[$1]="${SETOPT_KEYS_F[$1]}${setopt_pairs[$optkey]}"
  }
  win_ctx_op 'pop'
}

get_key() {
  local key
  for((;;)){
    read ${READ_OPTS[@]} -N1 key
    # Continue loop if read times out from lack of input
    (($?>128)) && continue
    # Handling escape characters
    [[ ${key} == $'\x1B' ]] && {
      read ${READ_OPTS[@]} -N1
      # Handling CSI (Control Sequence Introducer) sequences ('[' + sequence)
      [[ "${REPLY}" != "[" ]] && return 0 || read ${READ_OPTS[@]} -N2
      key=$'\x9B'${REPLY}
    }
    case ${key} in
      $'\n') return 1;;# ENTER
      k|$'\x9BA') return 2;;# UP
      j|$'\x9BB') return 3;;# DOWN
      h|$'\x9BD') return 4;;# LEFT
      l|$'\x9BC') return 5;;# RIGHT
      $'\x9B5~') return 6;;# PGUP
      $'\x9B6~') return 7;;# PGDOWN
      $'\x20') return 8;;# SPACE
      $'\x9B1~') return 9;;# HOME
      $'\x9B4~') return 10;;# END
    esac
  }
}

nav_single() {
  local -i len lim
  local -n ref idx offs
  read -d '' _ _ lim _ <<< "${win_ctx[attr]//,/ }"
  ref=${win_ctx[nref]} idx=win_ctx[idx] offs=win_ctx[offset] len=${#ref[@]}
  ((lim-=2))
  print_pg
  for((;;)){
    get_key
    case $? in
      0) # ESC
        return 0
      ;;
      1) # ENTER
        [[ ${win_ctx[nref]} == 'setopt_pairs_f' ]] && {
          printf '  \x9B7m%s\x1B8' "${ref[$idx]}"
          seq_select $idx
        } || return 1
      ;;
      2) # UP
        # Ignore 0th index
        ((!idx)) && continue
        # If cursor on first line of page, decrement indices and print page
        # Else, remove highlight on current line before printing subsequent line
        ((idx==offs)) && { ((offs--,idx--)); print_pg; continue;} ||
          : "  ${ref[$((idx--))]},A"
      ;;&
      3) # DOWN
        # Ignore last index
        ((idx+1==len)) && continue
        # If cursor on last line of page, increment indices and print page
        # Else, remove highlight on current line before printing subsequent line
        ((idx+1==offs+lim)) && { ((offs++,idx++)); print_pg; continue;} ||
          : "  ${ref[$((idx++))]},B"
      ;&
      2) # UP/DOWN fallthrough
        [[ ${win_ctx[nref]} == 'setopt_pairs_f' ]] && {
          ((${#_}>COLUMNS-6)) && : "${_% *} ...${_: -2}"
          ((${#ref[$idx]}>COLUMNS-8)) && : "$_,${ref[$idx]% *} ..."
        } || : "$_,${ref[$idx]}"
        [[ $_ =~ ^(  .*),(.),(.*)$ ]] && {
          printf '%s\x1B8\x9B%s\x1B7' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
          printf '\xAF \x9B7m%s\x1B8' "${BASH_REMATCH[3]}"
        }
        #printf '  %s\x1B8\x9BB\x1B7' "${ref[$((idx++))]}"
        #printf '\xAF \x9B7m%s\x1B8' "${ref[$idx]}"
      ;;
      6) # PGUP
        ((offs=offs-lim>0?offs-lim:0))
        ((idx=idx-lim>0?idx-lim:0))
        print_pg
      ;;
      7) # PGDOWN
        ((offs+lim<len-lim)) && ((offs+=lim)) ||
          ((offs=len>lim?len-lim:0))
        ((idx=idx+lim<len?idx+lim:len-1))
        print_pg
      ;;
      9) # HOME
        offs=0; idx=0
        print_pg
      ;;
      10) # END
        ((offs=len>lim?len-lim:0,idx=len-1))
        print_pg
      ;;
    esac
  }
}

nav_multi() {
  local -i len lim
  local -n ref idx offs
  idx=win_ctx[idx]  offs=win_ctx[offset] ref=${win_ctx[nref]} len=${#ref[@]}
  read -d '' _ _ lim _ <<< "${win_ctx[attr]//,/ }"
  ((lim-=2))
  print_pg
  for((;;)){
    get_key
    case $? in
      0) # ESC
        return 0
      ;;
      1) # ENTER
        return 1
      ;;
      2) # UP
        # Ignore 0th index
        ((!idx)) && continue
        # If cursor on first line of page, decrement indices and print page
        # Else, remove highlight on current line before printing subsequent line
        ((idx==offs)) && { ((offs--,idx--)); print_pg;} || {
          printf ' \x9B5C%s\x1B8\x9BA\x1B7' "${ref[$((idx--))]}"
          printf '\xAF\x9B5C\x9B7m%s\x1B8' "${ref[$idx]}"
        }
      ;;
      3) # DOWN
        # Ignore last index
        ((idx+1==len)) && continue
        # If cursor on last line of page, increment indices and print page
        # Else, remove highlight on current line before printing subsequent line
        ((idx+1==offs+lim)) && { ((offs++,idx++)); print_pg;} || {
          printf ' \x9B5C%s\x1B8\x9BB\x1B7' "${ref[$((idx++))]}"
          printf '\xAF\x9B5C\x9B7m%s\x1B8' "${ref[$idx]}"
        }
      ;;
      6) # PGUP
        ((offs=offs-lim>0?offs-lim:0))
        ((idx=idx-lim>0?idx-lim:0))
        print_pg
      ;;
      7) # PGDOWN
        ((offs+lim<len-lim)) && ((offs+=lim)) ||
          ((offs=len>lim?len-lim:0))
        ((idx=idx+lim<len?idx+lim:len-1))
        print_pg
      ;;
      8) # SPACE
        [[ ${win_ctx[idxs]} == '-1' ]] && win_ctx[idxs]="$idx" || {
          [[ ${win_ctx[idxs]} =~ (^${idx},?|,?${idx}) ]] && {
            win_ctx[idxs]="${win_ctx[idxs]//${BASH_REMATCH[0]}}"
            [[ -z ${win_ctx[idxs]} ]] && win_ctx[idxs]='-1'
            printf '\x9B3C \x1B8' && continue
          } || win_ctx[idxs]+=",${idx}"
        }
        printf '\x9B3C\x04\x1B8'
      ;;
      9) # HOME
        offs=0 idx=0
        print_pg
      ;;
      10) # END
        ((offs=len>lim?len-lim:0,idx=len-1))
        print_pg
      ;;
    esac
  }
}

main() {
  trap 'cleanup' EXIT
  trap 'get_console_size; draw_window' SIGWINCH
  trap 'exit_prompt' SIGINT
  [[ $1 == -d ]] && test_size || set_console
  display_init
  parse_files
  seq_main
}
main "$@"
