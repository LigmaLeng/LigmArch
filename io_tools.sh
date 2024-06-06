#!/usr/bin/env bash
#
# TODO: Write file header
#
# TODO: pacman parallel downloads
# TODO: makepkg optimisations
# TODO: create /etc/systemd/sleep.conf.d/disable-sleep.conf
# [Sleep]
# AllowSuspend=no
# AllowHibernation=no
#
# TODO: add kernel parameters
# iommu=pt
# nvidia_drm.modeset=1
# nvidia_drm.fbdev=1
#
# TODO: add module parameters
# NVreg_UsePageAttributeTable=1
# NVreg_EnableStreamMemOPs=1
# NVreg_EnablePCIeGen3=1
# NVreg_EnableMSI=1
#
# TODO: target systemctl
# systemctl enable ... --root=/mnt
# TODO: rsync for boot backup hook on system upgrade
# TODO: incase i need to run sudo for user
# echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel_sudo
# echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel_sudo
#      cuda (NVIDIA)
#        gdb
#        glu
#        nvidia-utils
#        rdma-core
# 

[[ ${0%/*} == ${0} ]] && CTX_DIR='.' || CTX_DIR=${0%/*}
CACHE_DIR=${XDG_CACHE_HOME:=${HOME}/.cache/ligmarch}
TEMPLATE_PATH="${CTX_DIR}/options.setup"
READ_OPTS=(-rs -t 0.03)
readonly CTX_DIR CACHE_DIR TEMPLATE_PATH READ_OPTS
declare -i LINES COLUMNS TRANSVERSE SAGITTAL
declare -a SETOPT_KEYS SETOPT_KEYS_F setopt_pairs_f win_ctx_a
declare -A setopt_pairs win_ctx
win_ctx=(attr '' nref '' pg_type '' offset '' idx '' idxs '')
hash sort

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
  # ?7h   Enable line wrapping
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
  ((i=0,lim=(TRANSVERSE>>2)-(LINES&1)))
  # Widen pilot cleave if lines are odd
  # A M B L: up  delete_line  down  insert_line
  printf '\x9B%s;%sr\x9B%s;H' 2 $((TRANSVERSE+(2*lim)+(LINES&1))) $TRANSVERSE
  ((LINES&1)) && printf '\x9B%s' {A,M,B,L,A}
  # Continue widening
  for((i;i++<lim;)){ printf '\x9B%s' {A,M,B,2L,A}; nap 0.015;}
  printf '\x9Br'
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
          : "${ref[$i]}"
          ((${#_}>COLUMNS-8)) && {
            : "${_::$((COLUMNS-8))}"; : "${_%  *} ...";}
          printf '\x1B7  %s\x1B8\x9BB' "$_"
        }
        printf '\x9B%sA\x1B7  ' $((i-=w[idx]))
        : "${ref[$((lim-i))]}"
        ((${#_}>COLUMNS-8)) && {
          : "${_::$((COLUMNS-8))}"; : "${_%  *} ...";} || : "$_"
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

prompt() {
  local str white_sp i
  white_sp=$(echoes '\x20' 65)
  case $1 in
    'err')
      printf '%s\x1B8' "$white_sp"
      for((i=0;i++<9;)){
        ((i&1)) && printf '\x9B7m'
        printf '%s\x1B8' "$2"; nap 0.07
        read ${READ_OPTS[@]}
      }
    ;;
    'new')
      printf '  %s\x1B8\x9BB  %s\x1B8\x9B2B' "$white_sp" "$white_sp"
      printf '  %s\x1B8' "$white_sp"
      : "${win_ctx[offset]}"
      printf '\xAF ENTER DESIRED %s\x1B8\x9BB' "${SETOPT_KEYS[$_]//_/ }"
      printf '  \x1B7\x9BB\x9BD:\x9B7m \x1B8' 
    ;;
    'update')
      printf '%s\x1B8\x9BB' "$white_sp" "$white_sp"
      : "${SETOPT_KEYS[${win_ctx[offset]}]}"
      [[ $_ =~ PASS$ ]] && { printf '\x9B7m \x1B8'; return;}
      str="${win_ctx[nref]}"
      ((i=${win_ctx[idx]}))
      printf '%s\x9B7m' "${str::${idx}}"
      ((idx==${#str})) && printf ' \x1B8' ||
        printf '%s\x9B27m%s\x1B8' "${str:${idx}:1}" "${str:$((idx+1))}"
    ;;
  esac
}

win_ctx_op() {
  local -n w wa
  local attr
  w=win_ctx; wa=win_ctx_a
  case $1 in
    'set')
      read -d '' w[attr] w[nref] w[pg_type] <<< "${2//;/ }"
      ((w[offset]=0,w[idx]=0,w[idxs]=-1))
    ;;
    'push')
      [[ ${w[pg_type]} == 'prompt' ]] && w[nref]="__${w[nref]}"
      : "${w[attr]};${w[nref]};${w[pg_type]};${w[offset]};${w[idx]};${w[idxs]}"
      win_ctx_a+=("$_")
    ;;
    'pop')
      # Inner dimensions
      for i in ${wa[@]};{
        : "${i//;/ }"
        read -d '' w[attr] w[nref] w[pg_type] w[offset] w[idx] w[idxs] <<< "$_"
        draw_window
        [[ ${w[pg_type]} == 'prompt' ]] && { w[nref]="${w[nref]#__}";} ||
          print_pg 'nocurs'
      }
      [[ ${w[pg_type]} != 'prompt' ]] && printf '\xAF\x9BD' || {
        prompt 'new'
        [[ -n "${w[nref]}" ]] && { prompt 'update';}
      }
      unset wa[-1]
    ;;
  esac
  return 0
}

exit_prompt() {
  local exit_query exit_opts
  [[ ${FUNCNAME[1]} == 'exit_prompt' ]] && return
  exit_query='Abort setup process'; exit_opts=('(Y|y)es' '(N|n)o')
  [[ "${1:-}" == 'config' ]] && exit_query="Config error: ${exit_query}"
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

options_init() {
  local lim key i
  lim=0
  # Create cache directory if non-existent
  [[ -d $CACHE_DIR ]] || mkdir -p $CACHE_DIR
  # Parse config template
  while read; do
    case $REPLY in
      # Brackets demarcate separate sections while parsing values that
      # correspond to the resulting header string after trimming '[' & ']'
      '['*)
        : "${REPLY#[}"
        key="${_%]}"
        [[ ${key::1} == '.' ]] && {
          key="${SETOPT_KEYS[-1]}_${key:1}"; continue;}
        SETOPT_KEYS+=("$key")
        # Keep track of longest optkey for page formatting purposes
        ((lim=${#key}>lim?${#key}:$lim))
      ;;
      value*)
        setopt_pairs[$key]=${REPLY#*= }
      ;;
      list*|option*)
        declare -ga $key
        local -n ref=$key
        while read; do
          [[ -z $REPLY ]] && break
          ref+=("${REPLY#"${REPLY%%[![:space:]]*}"}")
          setopt_pairs[$key]+="  ${ref[-1]}"
        done
        [[ $key =~ ^(PACKAGES|MOUNT*) ]] && {
          : "${setopt_pairs[$key]#  }"  
        } || : "${ref[0]}"
        setopt_pairs[$key]="$_"
        [[ $key == 'MIRRORS' ]] && ref=()
        [[ $key == PACKAGES* ]] && {
          [[ -v PACKAGES ]] || declare -ga PACKAGES
          PACKAGES+=("${key##PACKAGES_}")
        }
      ;;
    esac
  done < "$TEMPLATE_PATH"
  # Format spacing for printing setup options
  for((i=-1;++i<${#SETOPT_KEYS[@]};)){
    key="${SETOPT_KEYS[$i]}"
    : "${key//_/ }"
    SETOPT_KEYS_F+=("${_}$(echoes '\x20' $((lim-${#_}+3)))")
    setopt_pairs_f+=("${SETOPT_KEYS_F[-1]}${setopt_pairs[$key]}")
    [[ $key =~ ^(.*NAME|.*PASS)$ ]] && setopt_pairs[$key]=''
  }
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
  # Get zoneinfo files
  TIMEZONE=($(timedatectl list-timezones))
  # Parse supported locales and format spacing for printing
  ((lim=SAGITTAL-4))
  while read; do
    LOCALE+=("${REPLY% *}$(echoes '\x20' $((lim-${#REPLY})))${REPLY#* }")
  done < "/usr/share/i18n/SUPPORTED"
  # Retrieve block devices from sysfs
  for key in /sys/block/*;{
    [[ $key =~ (sd|hd|nvme) ]] || continue
    i=$(<"$key/size")
    ((i=i*5120>>30))
    BLOCK_DEVICE+=("/dev/${key##*/} "$'\xF7'" ${i:: -1}.${i: -1}Gib")
  }
  for key in ${SETOPT_KEYS};{
    [[ $key =~ (SIZE|PASS|NAME)$ ]] || readonly $key;}
  # Append option keys relevant to config based actions
  for key in {SAVE_CONFIG,LOAD_CONFIG,INSTALL};{
    SETOPT_KEYS+=("$key")
    setopt_pairs_f+=("[${key/_/ }]")
  }
  readonly SETOPT_KEYS SETOPT_KEYS_F ${PACKAGES[@]}
}

draw_window() {
  local y x m n offset horz vert
  read -d '' y x m n <<< "${win_ctx[attr]//,/ }"
  ((offset=0))
  horz=$(echoes '\xCD' $((n-2))); vert="\xBA\x9B$((n-2))C\xBA"
  # Cursor origin and print top border
  printf '\x9B%s;%sH\xC9%s\xBB' $y $x $horz
  # Print vertical borders on every line but first and last
  for((;offset++<m-2;)){ printf '\x9B%s;%sH%b' $((y+offset)) $x $vert;}
  # Print bottom border
  printf '\x9B%s;%sH\xC8%s\xBC' $((y+m-1)) $x $horz
  # Bring cursor into window, save cursor state
  printf '\x9B%s;%sH\x1B7' $((y+1)) $((x+1))
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
  nav_single
}

seq_select() {
  local -n w ref
  local optkey i
  w=win_ctx
  [[ ${w[nref]} == PACKAGES ]] && : "PACKAGES_${PACKAGES[$1]}" ||
    : "${SETOPT_KEYS[$1]}"
  optkey=$_; ref=$optkey
  win_ctx_op 'push'
  # Refer to corresponding arrays and attributes belonging to option key
  : "2,${SAGITTAL},$((${#ref[@]}<LINES-4?${#ref[@]}+2:LINES-2)),$((SAGITTAL-1))"
  [[ $optkey =~ ^(MIRRORS|PACKAGES_|MOUNT*) ]] && {
    : "$_;${optkey};multi";} || : "$_;${optkey};single"
  win_ctx_op 'set' "$_"
  # If option accepts multiple values, convert string values to indices
  [[ ${w[pg_type]} == 'multi' && "${setopt_pairs[$optkey]}" != 'unset' ]] && {
    for((i=-1;++i<${#ref[@]};)){
      [[ "${setopt_pairs[$optkey]}" =~ ${ref[$i]} ]] && w[idxs]+=",$i"
    }
    w[idxs]="${w[idxs]#-1,}"
  }
  draw_window
  nav_${w[pg_type]} && { win_ctx_op 'pop'; return;}
  [[ ${w[pg_type]} == multi ]] && {
    # If option supports multiple values, convert indices to string values
    [[ "${w[idxs]}" == '-1' ]] && setopt_pairs[$optkey]='unset' || {
      setopt_pairs[$optkey]=''
      while read; do
        setopt_pairs[$optkey]+="  ${ref[$REPLY]}"
      done < <(sort -n <<< "${w[idxs]//,/$'\n'}")
      setopt_pairs[$optkey]="${setopt_pairs[$optkey]#  }"
    }
    [[ $optkey == PACKAGES* ]] && { win_ctx_op 'pop'; return;}
  }
  [[ ${w[pg_type]} == single ]] && {
    : "${ref[${w[idx]}]}"
    [[ $optkey =~ ^(LOCALE|BLOCK_DEVICE) ]] && : "${_%% *}"
    setopt_pairs[$optkey]="$_"
  }
  setopt_pairs_f[$1]="${SETOPT_KEYS_F[$1]}${setopt_pairs[$optkey]}"
  win_ctx_op 'pop'
}

seq_ttin() {
  local -n str idx
  local optkey key strcomp lim
  win_ctx_op 'push'
  win_ctx_op 'set' "2,$((COLUMNS-70)),5,69;__;prompt"
  str=win_ctx[nref]; idx=win_ctx[idx]; win_ctx[offset]=$1
  optkey=${SETOPT_KEYS[$1]}; str=''; strcomp=''
  case $optkey in 'ESP'|'USERNAME') : 32;; 'HOSTNAME') : 64;; *) : 0;;esac
  ((idx=0,lim=$_))
  draw_window
  prompt 'new'
  for((;;)){
    get_key key
    case $key in
      $'\x0A') # ENTER
        [[ -z "$str" ]] && { prompt 'err' "NO INPUT RECEIVED"; continue;}
        case $optkey in
          'USERNAME')
            [[ "$str" =~ .*[$].*.$ ]] && {
              prompt 'err' "'$' ONLY VALID AS LAST CHARACTER"; continue;}
          ;;&
          ESP*|*VOLUME_SIZE)
            ! [[ "$str" =~ ^([1-9][0-9]*)G(iB)?$ ]] && {
              prompt 'err' "VALID SPECIFIERS: [:digit:]G(iB)"; continue;}
            str="${BASH_REMATCH[1]}GiB"
          ;;&
          *PASS)
            [[ -z "$strcomp" ]] && {
              strcomp="$str"; str=''
              ((idx=0))
              printf '\x9BARE-ENTER %s TO CONFIRM\x1B8' "$optkey"; continue
            } || {
              [[ "$strcomp" != "$str" ]] && {
                strcomp=''; str=''
                printf '\x9BAENTER DESIRED %s      \x1B8' "${optkey//_/ }"
                prompt 'err' "INVALID MATCH"; continue
              }
            }
            : "hidden"
          ;;
          *) : "$str";;
        esac
        setopt_pairs_f[$1]="${SETOPT_KEYS_F[$1]}${_}"
        setopt_pairs[$optkey]="$str"
      ;&
      $'\x1B') win_ctx_op 'pop'; return;; # ESC
      $'\x9BD') ((idx>0)) && ((idx--));; # LEFT
      $'\x9BC') : "$str"; ((idx<${#_})) && ((idx++));; # RIGHT
      $'\x7F') # BACKSPACE
        : "$str"; ((${#_}&&idx)) && str="${_::$((idx-1))}${_:$((idx--))}";;
      $'\x9B3~') # DEL
        : "$str"; ((idx<${#_})) && str="${_::${idx}}${_:$((idx+1))}";;
      $'\x9B1~') ((idx=0));; # HOME
      $'\x9B4~') : "$str"; ((idx=${#_}));; # END
      *)
        # Broad key validation: if failed, print warning and flush input buffer
        [[ "${key}" =~ ^[[:alnum:][:punct:]]$ ]] || {
          prompt 'err' 'INVALID KEY'; continue;}
        # String length validation
        : "$str"; ((lim&&${#_}>=lim)) && {
          prompt 'err' "${lim} CHARACTER LIMIT"; continue;}
        # Regex validation for valid patterns
        case $optkey in
          'HOSTNAME')
            [[ "${key}" =~ [a-z0-9-] ]] || {
              prompt 'err' 'VALID CHARACTERS: [a-z,0-9,-]'; continue;}
          ;;
          'USERNAME')
            ((!idx)) && {
              [[ "${key}" =~ [[:alpha:]_] ]] || {
                prompt 'err' 'VALID 1ST CHARACTERS: [a-z,A-Z,_]'; continue;}
            } || {
              [[ "${key}" =~ [[:alpha:]_\$-] ]] || {
                prompt 'err' 'VALID CHARACTERS: [a-z,A-Z,_,-,$]'; continue;}
            }
          ;;
        esac
        str="${str::${idx}}${key}${str:$((idx++))}"
      ;;
    esac
    prompt 'update'
  }
}

nav_single() {
  local -n ref idx offs
  local key len y x lim n slim
  ref=${win_ctx[nref]}; idx=win_ctx[idx]; offs=win_ctx[offset]; len=${#ref[@]}
  read -d '' y x lim n <<< "${win_ctx[attr]//,/ }"
  ((lim-=2)); ((slim=lim>>1))
  print_pg
  for((;;)){
    get_key key
    case $key in
      q|$'\x1B') # ESC
        [[ ${win_ctx[nref]} == 'setopt_pairs_f' ]] && exit_prompt || return 0
      ;;
      $'\x0A') # ENTER
        [[ ${win_ctx[nref]} == 'PACKAGES' ]] && {
          local white_sp=$(echoes '\x20' $n)
          printf '\x9B%s;%sH' $y $x
          for((i=0;i++<lim+2;)){ printf '\x1B7%s\x1B8\x9BB' "${white_sp}";}
          seq_select $idx
          continue
        }
        [[ ${win_ctx[nref]} == 'setopt_pairs_f' ]] || return 1
        : "${ref[$idx]}"
        ((${#_}>COLUMNS-8)) && {
          : "${_::$((COLUMNS-8))}"; : "${_%  *} ...";}
        printf '  \x9B7m%s\x1B8' "$_"
        case ${SETOPT_KEYS[$idx]} in
          ESP*|*VOLUME_SIZE|*NAME|*PASS) seq_ttin $idx;;
          SAVE*) save_config; printf '\xAF \x9B7m[   SAVED   ]\x1B8';;
          LOAD*)
            load_config
            (($?)) && : 'NO SAVEFILE' || : 'SAVE LOADED'
            printf '\xAF \x9B7m[%s]\x1B8' "$_"
          ;;
          INSTALL) install_config;;
          *) seq_select $idx;;
        esac
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
          ((${#_}>COLUMNS-4)) && {
            : "${_::$((COLUMNS-6))}${_: -2}"; : "${_%  *} ...${_: -2}";}
          ((${#ref[$idx]}>COLUMNS-8)) && {
            : "$_,${ref[$idx]::$((COLUMNS-8))}"
            : "${_%  *} ..."
          } || : "$_,${ref[$idx]}" 
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
      $'\x1B') return 0;; # ESC
      $'\x0A') return 1;; # ENTER
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
            [[ ${_: -1} == ',' ]] && {
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

save_config() {
  local key white_sp
  exec {save_fd}>${CACHE_DIR}/options.conf
  for key in ${SETOPT_KEYS[@]};{
    [[ $key =~ ^(PACKAGES|.*PASS|.*CONFIG|INSTALL)$ || -z "${setopt_pairs[$key]}" ]] &&
      continue
    printf '%s\n' "[$key]" >&$save_fd
    [[ $key =~ ^(MIRRORS|MOUNT*) ]] && {
      printf 'list =\n      ' >&$save_fd
      : "${setopt_pairs[$key]//  /$'\n',}"
      printf '%s\n\n' "${_//,/      }" >&$save_fd
    } || printf 'value = %s\n\n' "${setopt_pairs[$key]}" >&$save_fd
  }
  printf '[PACKAGES]\n' >&$save_fd
  for key in ${PACKAGES[@]};{
    printf '%s\nlist =\n      ' "[.$key]" >&$save_fd
    : "${setopt_pairs["PACKAGES_$key"]//  /$'\n',}"
    printf '%s\n\n' "${_//,/      }" >&$save_fd
  }
  exec {save_fd}>&-
}

load_config() {
  local key i
  [[ -a "${CACHE_DIR}/options.conf" ]] || return 1
  while read; do
    case $REPLY in
      '['*) : "${REPLY#[}"; key="${_%]}";;
      value*) setopt_pairs[$key]=${REPLY#*= };;
      list*)
        key=${key/#./PACKAGES_}
        setopt_pairs[$key]=''
        while read; do
          [[ -z $REPLY ]] && break ||
            setopt_pairs[$key]+="  ${REPLY#"${REPLY%%[![:space:]]*}"}"
        done
        setopt_pairs[$key]="${setopt_pairs[$key]#  }"
      ;;
    esac
  done < "${CACHE_DIR}/options.conf"
  for((i=-1;++i<${#SETOPT_KEYS_F[@]};)){
    key="${SETOPT_KEYS[$i]}"
    [[ $key == PACK* ]] && continue
    [[ $key == *PASS ]] && { setopt_pairs[$key]=''; : 'unset';} ||
      : "${setopt_pairs[$key]}"
    setopt_pairs_f[$i]="${SETOPT_KEYS_F[$i]}$_"
  }
  print_pg
}

setup_partitions() {
  local -n opt
  local -a flags
  opt=setopt_pairs
  flags=(-v -t ext4 -O casefold,fast_commit)
  umount -q ${opt[BLOCK_DEVICE]}
  wipefs -af ${opt[BLOCK_DEVICE]}
  sgdisk -Zo ${opt[BLOCK_DEVICE]}
  sgdisk -I -n 1:0:+${opt[ESP_SIZE]%iB} -t 1:EF00 ${opt[BLOCK_DEVICE]}
  sgdisk -I -n 2:0:0 -t 2:8E00 ${opt[BLOCK_DEVICE]}
  partprobe ${opt[BLOCK_DEVICE]}
  mkfs.fat -F 32 "${opt[BLOCK_DEVICE]}p1"
  [[ "${opt[EXT4_BLOCK_SIZE]}" == 'default' ]] && {
    : "${opt[BLOCK_DEVICE]}p2"
  } || : "--dataalignment ${opt[EXT4_BLOCK_SIZE]%B} ${opt[BLOCK_DEVICE]}p2"
  pvcreate $_
  vgcreate vg0 "${opt[BLOCK_DEVICE]}p2"
  lvcreate -y -L "${opt[ROOT_VOLUME_SIZE]}%iB" vg0 -n lv0
  lvcreate -y -L "${opt[HOME_VOLUME_SIZE]}%iB" vg0 -n lv1
  modprobe dm_mod
  vgscan
  vgchange -ay
  [[ "${opt[EXT4_BLOCK_SIZE]}" == 'default' ]] && {
    mke2fs ${flags[@]} /dev/vg0/lv0
  } || mke2fs ${flags[@]} -b ${opt[EXT4_BLOCK_SIZE]%B} /dev/vg0/lv0
  flags+=(-m 0 -T largefile)
  [[ "${opt[EXT4_BLOCK_SIZE]}" == 'default' ]] ||
    flags+=(-b ${opt[EXT4_BLOCK_SIZE]%B})
  mke2fs ${flags[@]} /dev/vg0/lv1
  [[ "${opt[MOUNT_OPTIONS]}" == 'unset' ]] || {
    tune2fs -E mount_opts="${opt[MOUNT_OPTIONS]//  / }" /dev/vg0/lv0
    tune2fs -E mount_opts="${opt[MOUNT_OPTIONS]//  / }" /dev/vg0/lv1
  }
  mount /dev/vg0/lv0 /mnt
  mount --mkdir ${opt[BLOCK_DEVICE]}p1 /mnt/efi
  mount --mkdir /dev/vg0/lv1 /mnt/home
}

setup_mirrors() {
  local i
  pacman -S pacman-contrib --noconfirm --needed
  [[ -a "/etc/pacman.d/mirrorlist.bak" ]] ||
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
  exec {mirror_fd}>${CACHE_DIR}/mirrors
  while read; do
    [[ "$REPLY" == '##'* ]] || continue
    [[ "${setopt_pairs[MIRRORS]}" =~ "${REPLY#* }" ]] && {
      while read; do
        [[ -z $REPLY ]] && break
        printf '%s\n' "${REPLY#\#}" >&$mirror_fd
      done
    }
  done < "${CACHE_DIR}/mirrorlist"
  exec {mirror_fd}>&-
  rankmirrors ${CACHE_DIR}/mirrors > /etc/pacman.d/mirrorlist
}

edit_pacconf() {
  local stream
  read -d '' -r stream < /etc/pacman.conf
  exec {stream_fd}>/etc/pacman.conf
  while read; do
    case $REPLY in
      '#[multilib]') printf '[multilib]\n' >&$stream_fd; read;&
      '#ParallelDownloads'*) : "${REPLY#\#}";;
      *) : "$REPLY";;
    esac
    printf '%s\n' "$_" >&$stream_fd
  done <<< "$stream"
  exec {stream_fd}>&-
}

strapon() {
  local -a pkg_base
  pkg_base=(base base-devel dosfstools e2fsprogs lvm2 pacman-contrib)
  edit_pacconf
  while read; do
    [[ $REPLY == vendor_id* ]] && {
      [[ $REPLY =~ AMD ]] && : 'amd-ucode' || : 'intel-ucode'
      pkg_base+=("$_")
      break
    } || continue
  done < /proc/cpuinfo
  pkg_base+=(${setopt_pairs[KERNEL]} "${setopt_pairs[KERNEL]}-headers")
  pacstrap -KP /mnt ${pkg_base[@]}
}

setup_localisation() {
  local stream
  printf '%s\n' "${setopt_pairs[HOSTNAME]}" > /mnt/etc/hostname
  read -d '' -r stream < /mnt/etc/locale.gen
  exec {stream_fd}>/mnt/etc/locale.gen
  while read; do
    : "$REPLY"
    [[ "$_" == "#${setopt_pairs[LOCALE]} "* ]] && : "${_#\#}"
    printf '%s\n' "$_" >&$stream_fd
  done <<< "$stream"
  exec {stream_fd}>&-
  printf 'LANG=%s\n' "${setopt_pairs[LOCALE]}" > /mnt/etc/locale.conf
  printf 'KEYMAP=%s\n' "${setopt_pairs[KEYMAP]}" > /mnt/etc/vconsole.conf
  #[[ "${setopt_pairs[PACKAGES_TERMINAL]}" =~ terminus-font ]] &&
    #printf 'FONT=ter-i32b\n' >> /mnt/etc/vconsole.conf
  printf '127.0.0.1 localhost\n::1 localhost\n' > /mnt/etc/hosts
  printf '127.0.1.1 %s.localdomain %s\n' $HOSTNAME $HOSTNAME >> /mnt/etc/hosts
}

setup_chroot() {
  local stream
  genfstab -U /mnt >> /mnt/etc/fstab
  : "ln -sf /usr/share/zoneinfo/${setopt_pairs[TIMEZONE]} /etc/localtime"
  arch-chroot /mnt /bin/bash -c "${_}; hwclock --systohc; locale-gen"
  printf '%s\n' "${setopt_pairs[HOSTNAME]}" > /mnt/etc/hostname
  read -d '' -r stream < /mnt/etc/mkinitcpio.conf
  exec {stream_fd}>/mnt/etc/mkinitcpio.conf
  while read; do
    : "$REPLY"
    [[ "$_" == HOOKS* ]] && {
      : "HOOKS=(systemd autodetect microcode modconf keyboard"
      : "$_ sd-vconsole block lvm2 filesystems fsck)"
    }
    printf '%s\n' "$_" >&$stream_fd
  done <<< "$stream"
  exec {stream_fd}>&-
  arch-chroot /mnt mkinitcpio -p ${setopt_pairs[KERNEL]}
  arch-chroot /mnt bootctl --esp-path=/efi install
  printf 'root:%s\n' "${setopt_pairs[ROOTPASS]}" > >(arch-chroot /mnt chpasswd)
  arch-chroot /mnt useradd -m -g users -G wheel ${setopt_pairs[USERNAME]}
  : "${setopt_pairs[USERNAME]}:${setopt_pairs[USERPASS]}"
  printf '%s\n' "$_" > >(arch-chroot /mnt chpasswd)
}

setup_zram() {
  local size
  while read; do
    [[ "$REPLY" == MemTotal* ]] && {
      : "${REPLY% kB}"; size=${_##* }; size=$(((size>>20)/2))
      break
    }
  done < /proc/meminfo
  printf 'zram\n' > /mnt/etc/modules-load.d/zram.conf
  printf 'ACTION=="add", KERNEL=="zram0"' > /mnt/etc/udev/rules.d/99-zram.rules
  printf ', ATTR{comp_algorithm}="zstd"' >> /mnt/etc/udev/rules.d/99-zram.rules
  : ", ATTR{disksize}=\"${size}Gib\", RUN=\"/usr/bin/mkswap -U clear /dev/%k\""
  printf '%s, TAG+="systemd"' "$_" >> /mnt/etc/udev/rules.d/99-zram.rules
  printf '/dev/zram0 none swap defaults,pri=100 0 0' >> /mnt/etc/fstab
# TODO: disable zswap
# add zswap.enabled=0 to kernel params
#

}

install_extra_packages() {
  :
}

install_config() {
  local key i
  local -n opt
  opt=setopt_pairs
  exec {log_fd}>"${CACHE_DIR}/setup.log"
  # Check options
  for key in {MIRRORS,BLOCK_DEVICE};{
    [[ ${opt[$key]} == 'unset' ]] && { exit_prompt 'config'; return;}
  }
  for key in {ROOTPASS,USERNAME,USERPASS,HOSTNAME};{
    [[ -z "${opt[$key]}" ]] && { exit_prompt 'config'; return;}
  }
  for ((i=0;i<${#BLOCK_DEVICE[@]};i++)){
    key="${BLOCK_DEVICE[$i]}"
    [[ "$key" == "${opt[BLOCK_DEVICE]}"* ]] && {
      ((i=${opt[ROOT_VOLUME_SIZE]%GiB})); ((i+=${opt[HOME_VOLUME_SIZE]%GiB}))
      : "${key##* }"; : "${_%.*}"
      (($_<i)) && { exit_prompt 'config'; return;} || break
    }
  }
  setup_partitions >&$log_fd 2>&1
  setup_mirrors >&$log_fd 2>&1
  strapon
  setup_localisation
  setup_chroot
  exec {log_fd}>&-
  exit 0
}

main() {
  trap 'cleanup' EXIT
  trap 'get_console_size; draw_window' SIGWINCH
  trap 'exit_prompt' SIGINT
  [[ $1 == -d ]] && test_size || set_console
  display_init
  options_init 
  seq_main
}
main "$@"
