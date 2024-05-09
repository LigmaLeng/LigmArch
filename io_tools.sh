#!/usr/bin/env bash
#
# TODO: Write file header

[[ ${0%/*} == ${0} ]] && CTX_DIR='.' || CTX_DIR=${0%/*}
CACHE_DIR=${XDG_CACHE_HOME:=${HOME}/.cache/ligmarch}
TEMPLATE_DIR="${CTX_DIR}/options.conf"
READ_OPTS=(-rs -t 0.02)
readonly CTX_DIR CACHE_DIR TEMPLATE_DIR READ_OPTS
declare -i LINES COLUMNS TRANSVERSE SAGITTAL
declare -a SETOPT_KEYS SETOPT_KEYS_F
declare -a KEYMAP LOCALE MIRRORS KERNEL EDITOR PACKAGES
declare -a setopt_pairs_f win_ctx_a
declare -A setopt_pairs win_ctx
win_ctx=(attr '' nref '' pg_type '' offset '' idx '' idxs '')

die() {
  local -a bash_trace
  bash_trace=(${BASH_SOURCE[1]} ${BASH_LINENO[0]} ${FUNCNAME[1]})
  printf '\x9B%s' m 2J r
  printf '%s: line %d: %s: %s\n' ${bash_trace[@]} "${1-Died}" >&2
  printf 'press any key to continue'
  for((;;)){ read ${READ_OPTS[@]} -N1; (($?>128)) || exit 1;}
}

echoes()for((i=0;i++<$2;)){ printf $1;}

nap() {
  # Open file descriptor if doesn't exist pipe empty subshell
  [[ -n "${nap_fd:-}" ]] || { exec {nap_fd}<> <(:);}
  # Attempt to read from empty file descriptor for 1 ms if no timeout specified
  read -t ${1:-0.001} -u $nap_fd || :
}

set_console() {
  # Use ANSI-C standard for language collation
  readonly LC_ALL=C
  # Backup and modify stty settings for io operations (restored on exit)
  readonly STTY_BAK=$(stty -g)
  stty -echo -icanon -ixon isig susp undef
  #stty -echo -icanon -ixon isig susp undef
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
  local fissure i lim
  fissure=$(echoes '\xC4' $((COLUMNS-2)))
  # Place cursor on transverse plane
  printf '\x9B%s;H' $TRANSVERSE
  # Grow fissure from from saggital plane laterally along transverse plane
  ((i=-1,lim=SAGITTAL-1))
  for((i;++i<lim;)){
    printf '\x9B%sG\xCD' $((SAGITTAL-i)) $((SAGITTAL+i+!(COLUMNS&1)))
    nap 0.002
  }
  # Ligate fissure
  echoes '\xCE\x0D' 2 && nap 0.075
  # Pilot cleavage and swap ligatures
  printf '\xD0%b' $fissure '\n'
  printf '\xD2%b' $fissure '\x9BA\x0D'
  # Widen pilot cleave if lines are odd
  # A M B L: up  delete_line  down  insert_line
  ((LINES&1)) && printf '\x9B%s' {A,M,B,L,A}
  # Continue widening
  ((i=0,lim=(TRANSVERSE>>2)-(LINES&1)))
  for((i;i++<lim;)){ printf '\x9B%s' {A,M,B,2L,A}; nap 0.015;}
}

print_pg() {
  local i y x m n lim offs
  local -n w ref
  local white_sp
  w=win_ctx; ref=${w[nref]}; offs=${w[offset]}
  read -d '' y x m n <<< "${w[attr]//,/ }"
  ((m-=2,n-=2))
  ((lim=offs+m<${#ref[@]}?offs+m:${#ref[@]}))
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
      ((i=offs-1))
      for((i;++i<lim;)){ printf '\x1B7  < > %s\x1B8\x9BB' "${ref[$i]}";}
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
  w=win_ctx; wa=win_ctx_a
  case $1 in
    'set')
      read -d '' w[attr] w[nref] w[pg_type] <<< "${2//;/ }"
      ((w[offset]=0,w[idx]=0,w[idxs]=-1))
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
    ;;
  esac
  return 0
}

exit_prompt() {
  local exit_query exit_opts
  [[ ${FUNCNAME[1]} == 'exit_prompt' ]] && return
  exit_query='Abort setup process'; exit_opts=('(Y|y)es' '(N|n)o')
  win_ctx_op 'push'
  display_cleave
  # Center cursor
  printf '\x9B%s;%sH' $((TRANSVERSE-(LINES&1))) $SAGITTAL
  # Pad strings if columns are odd
  ((COLUMNS&1)) && { exit_query+=' '; exit_opts[0]+=' ';}
  # Finalise query and concatenate option strings
  exit_query+='?'; exit_opts="${exit_opts[0]}   ${exit_opts[1]}"
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
  local lim key
  lim=0
  # Create cache directory if non-existent
  [[ -d $CACHE_DIR ]] || mkdir -p $CACHE_DIR
  # Parse config file
  while read; do
    case $REPLY in
      # Brackets demarcate separate sections while parsing values that
      # correspond to the resulting header string after trimming '[' & ']'
      '['*)
        : "${REPLY#[}"
        key=("${_%]}")
        SETOPT_KEYS+=("$key")
        # Keep track of longest optkey for page formatting purposes
        ((lim=${#key}>lim?${#key}:$lim))
      ;;
      value*)
        setopt_pairs[$key]=${REPLY#*= }
      ;;
      list*)
        read setopt_pairs[$key]
        while read; do
          [[ -z $REPLY ]] && {
            setopt_pairs[$key]="${setopt_pairs[$key]#  }" && break
          } || { setopt_pairs[$key]+="  ${REPLY//[[:space:]]}";}
        done
        [[ $key =~ ^(KERNEL|EDITOR|PACKAGES) ]] && {
          local -n ref=$key
          ref=(${setopt_pairs[$key]})
          [[ $key != 'PACKAGES' ]] && setopt_pairs[$key]=${ref[0]}
        }
      ;;
    esac
  done < "$TEMPLATE_DIR"
  # Format spacing for printing setup options
  for i in ${SETOPT_KEYS[@]};{
    SETOPT_KEYS_F+=("${i/_/ }$(echoes '\x20' $((lim-${#i}+3)))");}
  # Retrieve currently active mirrors from cache if available
  # Else retrieve current mirrorlist from official mirrorlist generator page
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
  ((lim=SAGITTAL-4))
  while read; do
    LOCALE+=("${REPLY% *}$(echoes '\x20' $((lim-${#REPLY})))${REPLY#* }")
  done < "/usr/share/i18n/SUPPORTED"
  declare -r SETOPT_KEYS SETOPT_KEYS_F KEYMAP MIRRORS LOCALE
}

draw_window() {
  local y x m n offset horz vert
  : "${1:-${win_ctx[attr]}}"
  read -d '' y x m n <<< "${_//,/ }"
  ((offset=0))
  horz=$(echoes '\xCD' $((n-2))); vert="\xBA\x9B$((n-2))C\xBA"
  # Cursor origin and print top border
  printf '\x9B%s;%sH\xC9%s\xBB' $y $x $horz
  # Print vertical borders on every line but first and last
  for((;offset++<m-2;)){ printf '\x9B%s;%sH%b' $((y+offset)) $x $vert;}
  # Print bottom border
  printf '\x9B%s;%sH\xC8%s\xBC' $((y+m-1)) $x $horz
  # Bound scrolling region, bring cursor into window, save cursor state
  printf '\x9B%s;%sr\x9B%s;%sH\x1B7' $((y+1)) $((y+m-2)) $((y+1)) $((x+1))
}

get_key() {
  local -n ref
  ref=${1}
  for((;;)){
    read ${READ_OPTS[@]} -N1 ref
    # Continue loop if read times out from lack of input
    (($?>128)) && continue
    # Handling escape characters
    [[ ${ref} == $'\x1B' ]] && {
      read ${READ_OPTS[@]} -N1
      # Handling CSI (Control Sequence Introducer) sequences ('[' + sequence)
      [[ "${REPLY}" != "[" ]] && return || read ${READ_OPTS[@]} -N2
      ref=$'\x9B'${REPLY}
    }
    return
  }
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
  optkey=${SETOPT_KEYS[$1]}; ref=$optkey; w=win_ctx
  win_ctx_op 'push'
  # Refer to corresponding arrays and attributes belonging to option key
  : "2,${SAGITTAL},$((${#ref[@]}<LINES-4?${#ref[@]}+2:LINES-2)),$((SAGITTAL-1))"
  [[ $optkey =~ ^(MIRRORS|PACKAGES)$ ]] && {
    : "$_;${optkey};multi";} || : "$_;${optkey};single"
  win_ctx_op 'set' "$_"
  # If option supports multiple values, convert string values to indices
  [[ ${w[pg_type]} == 'multi' && "${setopt_pairs[$optkey]}" != 'unset' ]] && {
    for((i=-1;++i<${#ref[@]};)){
      [[ "${setopt_pairs[$optkey]}" =~ ^${ref[$i]}[[:space:]]* ]] && {
        setopt_pairs[$optkey]="${setopt_pairs[$optkey]/${BASH_REMATCH[0]}}"
        w[idxs]+=",$i"
      }
    }
    w[idxs]="${w[idxs]#-1,}"
  }
  draw_window
  win_ctx_op 'nav'
  (($?)) || {
    [[ ${w[pg_type]} == 'multi' ]] && {
      setopt_pairs[$optkey]=''
      # If option supports multiple values, convert indices to string values
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

seq_ttin() {
  local -n w
  local optkey key str lim white_sp re idx
  w=win_ctx; optkey=${SETOPT_KEYS[$1]}; str=''; ((idx=0))
  case $optkey in
    'USERNAME') ((lim=31));;
    'HOSTNAME') ((lim=63));;
    *) ((lim=SAGITTAL-6));;
  esac
  white_sp=$(echoes '\x20' $((lim+2)))
  draw_window "2,${SAGITTAL},5,$((SAGITTAL-1))"
  printf '\xAF ENTER DESIRED %s\x1B8\x9B2B \x1B7' $optkey
  printf '\x9B%s;%sr\x1B8:\x9B7m \x1B8' 2 $((LINES-1))
  for((;;)){
    get_key key
    case $key in
      $'\x1B') return;; # ESC
      $'\x0A') :;; # ENTER
      $'\x9BD') ((idx>0)) && ((idx--));; # LEFT
      $'\x9BC') ((idx<${#str})) && ((idx++));; # RIGHT
      $'\x7F') # BACKSPACE
        ((${#str}&&idx)) && str="${str::$((idx-1))}${str:$((idx--))}";;
      $'\x9B3~') # DEL
        ((idx<${#str})) && str="${str::${idx}}${str:$((idx+1))}";;
      $'\x9B1~') ((idx=0));; # HOME
      $'\x9B4~') ((idx=${#str}));; # END
      *)
        [[ $optkey =~ NAME$ ]] && { ((${#str}<lim)) || continue;}
        ! [[ "${key}" =~ ^[[:alnum:][:punct:]]$ ]] && continue
        str="${str::${idx}}${key}${str:$((idx++))}"
      ;;
    esac
    printf '%s\x1B8:%s\x9B7m' "$white_sp" "${str::${idx}}"
    ((idx==${#str})) && printf ' \x1B8' ||
      printf '%s\x9B27m%s\x1B8' "${str:${idx}:1}" "${str:$((idx+1))}"
  }
}

nav_single() {
  local -n ref idx offs
  local key len lim slim
  ref=${win_ctx[nref]}; idx=win_ctx[idx]; offs=win_ctx[offset]; len=${#ref[@]}
  read -d '' _ _ lim _ <<< "${win_ctx[attr]//,/ }"
  ((lim-=2)); ((slim=lim>>1))
  print_pg
  for((;;)){
    get_key key
    case $key in
      $'\x1B') return 1;; # ESC
      $'\x0A') # ENTER
        [[ ${win_ctx[nref]} == 'setopt_pairs_f' ]] && {
          printf '  \x9B7m%s\x1B8' "${ref[$idx]}"
          [[ ${SETOPT_KEYS[$idx]} =~ (NAME|PASS)$ ]] && seq_ttin $idx ||
            seq_select $idx
        } || return 0
      ;;
      k|$'\x9BA') # UP
        # Ignore 0th index
        ((!idx)) && continue
        # If cursor position at top of page, decrement indices and print page
        # Else, remove highlight on current line before printing subsequent line
        # printing behaviour handled in fallthrough case statement below
        ((idx==offs)) && { ((offs--,idx--)); print_pg; continue;} ||
          : "  ${ref[$((idx--))]},A"
      ;;&
      j|$'\x9BB') # DOWN
        # Ignore last index
        ((idx+1==len)) && continue
        # If cursor position at bottom of page, increment indices and print page
        # Else, remove highlight on current line before printing subsequent line
        # printing behaviour handled in fallthrough case statement below
        ((idx+1==offs+lim)) && { ((offs++,idx++)); print_pg; continue;} ||
          : "  ${ref[$((idx++))]},B"
      ;&
      k|$'\x9BA') # UP/DOWN fallthrough
        [[ ${win_ctx[nref]} == 'setopt_pairs_f' ]] && {
          ((${#_}>COLUMNS-6)) && : "${_% *} ...${_: -2}"
          ((${#ref[$idx]}>COLUMNS-8)) && : "$_,${ref[$idx]% *} ..." ||
            : "$_,${ref[$idx]}" 
        } || : "$_,${ref[$idx]}"
        [[ $_ =~ ^(  .*),(.),(.*)$ ]] && {
          printf '%s\x1B8\x9B%s\x1B7' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
          printf '\xAF \x9B7m%s\x1B8' "${BASH_REMATCH[3]}"
        }
      ;;
      $'\x02'|$'\x9B5~') # PG_UP/CTRL+B
        ((offs=offs-lim>0?offs-lim:0)); ((idx=idx-lim>0?idx-lim:0))
        print_pg
      ;;
      $'\x15') # HALF_PG_UP(CTRL+U)
        ((idx=idx-slim>0?idx-slim:0)); ((idx<offs)) && ((offs=idx))
        print_pg
      ;;
      $'\x06'|$'\x9B6~') # PG_DOWN/CTRL+F
        ((offs+lim<len-lim)) && ((offs+=lim)) ||
          ((offs=len>lim?len-lim:0))
        ((idx=idx+lim<len?idx+lim:len-1))
        print_pg
      ;;
      $'\x04') # HALF_PG_DOWN(CTRL+D)
        ((idx=idx+slim<len?idx+slim:len-1))
        ((idx+1>offs+lim)) && ((offs+=(idx-offs-lim+1)))
        print_pg
      ;;
      $'\x9B1~') # HOME
        offs=0; idx=0
        print_pg
      ;;
      $'\x9B4~') # END
        ((offs=len>lim?len-lim:0,idx=len-1))
        print_pg
      ;;
    esac
  }
}

nav_multi() {
  local -n ref idx offs
  local key len lim slim
  ref=${win_ctx[nref]}; idx=win_ctx[idx]; offs=win_ctx[offset]; len=${#ref[@]}
  read -d '' _ _ lim _ <<< "${win_ctx[attr]//,/ }"
  ((lim-=2)); ((slim=lim>>1))
  print_pg
  for((;;)){
    get_key key
    case $key in
      $'\x1B') return 1;; # ESC
      $'\x0A') return 0;; # ENTER
      k|$'\x9BA') # UP
        # Ignore 0th index
        ((!idx)) && continue
        # If cursor on first line of page, decrement indices and print page
        # Else, remove highlight on current line before printing subsequent line
        ((idx==offs)) && { ((offs--,idx--)); print_pg;} || {
          printf ' \x9B5C%s\x1B8\x9BA\x1B7' "${ref[$((idx--))]}"
          printf '\xAF\x9B5C\x9B7m%s\x1B8' "${ref[$idx]}"
        }
      ;;
      j|$'\x9BB') # DOWN
        # Ignore last index
        ((idx+1==len)) && continue
        # If cursor on last line of page, increment indices and print page
        # Else, remove highlight on current line before printing subsequent line
        ((idx+1==offs+lim)) && { ((offs++,idx++)); print_pg;} || {
          printf ' \x9B5C%s\x1B8\x9BB\x1B7' "${ref[$((idx++))]}"
          printf '\xAF\x9B5C\x9B7m%s\x1B8' "${ref[$idx]}"
        }
      ;;
      $'\x02'|$'\x9B5~') # PG_UP/CTRL+B
        ((offs=offs-lim>0?offs-lim:0)); ((idx=idx-lim>0?idx-lim:0))
        print_pg
      ;;
      $'\x15') # HALF_PG_UP(CTRL+U)
        ((idx=idx-slim>0?idx-slim:0)); ((idx<offs)) && ((offs=idx))
        print_pg
      ;;
      $'\x06'|$'\x9B6~') # PG_DOWN/CTRL+F
        ((offs+lim<len-lim)) && ((offs+=lim)) ||
          ((offs=len>lim?len-lim:0))
        ((idx=idx+lim<len?idx+lim:len-1))
        print_pg
      ;;
      $'\x04') # HALF_PG_DOWN(CTRL+D)
        ((idx=idx+slim<len?idx+slim:len-1))
        ((idx+1>offs+lim)) && ((offs+=(idx-offs-lim+1)))
        print_pg
      ;;
      $'\x20') # SPACE
        [[ ${win_ctx[idxs]} == '-1' ]] && win_ctx[idxs]="$idx" || {
          [[ ${win_ctx[idxs]} =~ (^${idx},|,${idx},|,${idx}$|^${idx}$) ]] && {
            : "${BASH_REMATCH[0]}"
            [[ ${_:: -1} == ',' ]] && {
              [[ ${_:: 1} == ',' ]] && : "${win_ctx[idxs]/$_/,}" ||
                : "${win_ctx[idxs]#$_}"
            } || : "${win_ctx[idxs]%$_}"
            win_ctx[idxs]="$_"
            [[ -z ${win_ctx[idxs]} ]] && win_ctx[idxs]='-1'
            printf '\x9B3C \x1B8' && continue
          } || win_ctx[idxs]+=",${idx}"
        }
        printf '\x9B3C\x04\x1B8'
      ;;
      $'\x9B1~') # HOME
        offs=0; idx=0
        print_pg
      ;;
      $'\x9B4~') # END
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
