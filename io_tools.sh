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

export LANG=C
export LC_ALL=C
shopt -s globstar nullglob
readonly LIG_TMPDIR=$(mktemp -d)
readonly LIG_CACHE="${XDG_CACHE_HOME:=${HOME}/.cache}/ligmarch"
readonly LIG_OPT=(keymap locale timezone mirrors device {host,user}name packages save install)
readonly MIRRORGEN_URL="https://archlinux.org/mirrorlist/"
mkdir -p ${LIG_CACHE}
cd ${LIG_TMPDIR}
[[ ${0%/*} == ${0} ]]\
	&& readonly LIG_SRCDIR=${OLDPWD}\
	|| readonly LIG_SRCDIR=${0%/*}

main()
{
	trap 'cleanup' EXIT
	trap 'get_console_size; draw_window' SIGWINCH
	#trap 'exit_prompt' SIGINT
	setup_console
	setup_console
	for opt in "${LIG_OPT[@]}";{
		case $opt in
		save|install) :;;
		*) mkdir $opt;;&
		#mirrors)
			#fetch_mirrorlist > ./mirrors/page_file;;
		packages)
			process_config;;
		keymap)
			localectl list-keymaps > ./keymap/page_file;;
		locale)
			localectl list-locales > ./locale/page_file;;
		timezone)
			timedatectl list-timezones > ./timezone/page_file;;
		device)
			fetch_devices > ./device/page_file;;
		esac
	}
	get_console_size
}

add_function_key()
{
	local func_name=$1
	[[ $(type -t "${func_name}") == function ]]\
		|| die
	: "[${func_name/_/ }]"
	main_keylist_strs+="${_^^}"
	main_keylist+=("${func_name}")
}

add_option_key()
{
	[[ $2 =~ ^((single|nested|multi)_select|form)$ ]]\
		|| die
	local opt_name="$1"
	local -n wintype=${opt_name}_wintype
	declare -g ${!wintype}
	wintype="$2"
	[[ ${wintype} == form ]] && {
		declare -g ${opt_name}_tgt
	} || {
		declare -ga ${opt_name}_strs
		[[ ${wintype} == multi ]]\
			&& declare -ga ${opt_name}_tgt\
			|| declare -gi ${opt_name}_tgt
	}
	((${#opt_name}>${opt_pad:=0}-3))\
		&& opt_pad=${#opt_name}+3
	main_keylist+=("${opt_name}")
	main_keylist_strs+=("${opt_name^^}")
}

cleanup()
{
	# m     Reset Colours 
	# r     Reset scrolling region
	# 2J    Clear screen
	# ?25h  Show cursor
	# ?7h   Enable line wrapping
	printf '\x9B%s' m 2J r ?25h ?7h
	# Return character set back to UTF-8
	printf '\x1B%%G'
	[[ -a "${LIG_TMPDIR}/.stty" ]]\
		&& stty $(<"${LIG_TMPDIR}/.stty")
	[[ -d "${LIG_TMPDIR}" ]]\
		&& rm -rf "${LIG_TMPDIR}"
}

die()
{
	trap - EXIT
	cleanup
	: "${BASH_SOURCE[1]}: line ${BASH_LINENO[0]}: ${FUNCNAME[1]}: ${1:-Died}"
	printf '%s\n' "$_" >&2
	exit 1
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

draw_window()
{
	local blanks y x lines columns
	read -d '' _ y x lines columns _ _ <<< "${WINDOW_STACK[-1]//:/ }"
	printf -v blanks '%*s' $((lines > columns ? lines : columns)) ''
	: "${blanks::$((columns - 2))}"
	: "${_// /$'\xCD'}"
	# Position cursor, print top and bottom borders
	printf '\x9B%s;%sH\xC9%s\xBB' $y $x "$_"
	printf '\x9B%s;%sH\x1B7\xC8%s\xBC\x1B8\x9BA' $((y + lines - 1)) $x "$_"
	# Print vertical borders, bring cursor into window, save cursor state
	: "${blanks::$((lines - 2))}"
	: "${_// /$'\x1B7\xBA'${blanks::$((columns - 2))}$'\xBA\x1B8\x9BA'}"
	printf '%s\x1B8\x9BC\x1B7' "$_"
}

echoes()
{
	for ((i=0;i++<$2;)){ printf '%s' "$1";}
}

exit_prompt()
{
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

fifo_read_through()
{
	[[ -p "/proc/self/fd/${1:-'0'}" ]]\
		|| die 'Bad file descriptor'
	[[ -z "${2:-}" ]]\
		&& while read -u $1; do [[ -z "$REPLY" ]] && break; done\
		|| while read -u $1; do [[ "$REPLY" =~ $2 ]] && break; done
}

cache_country_codes()
{
	exec {dom_stream}<> <(curl -s "${MIRRORGEN_URL}")
	fifo_read_through ${dom_stream} "<select.*id=\"id_country\""
	fifo_read_through ${dom_stream} "<option.*value=\"all\""
	while read -u ${dom_stream} && [[ "${REPLY:-}" != *'</select>'* ]]; do
		[[ "$REPLY" =~ 'value="'(.*)'">'(.*)'<' ]]\
			|| continue
		# Quirk for literally the only multibyte char
		[[ ${BASH_REMATCH[1]} == TR ]]\
			&& printf 'TR Turkey\n'\
			|| printf '%s %s\n' "${BASH_REMATCH[@]:1:2}"
	done > "${LIG_CACHE}/country_codes"
	exec {dom_stream}>&-
}

fetch_mirrorlist()
{
	[[ -f "${LIG_CACHE}/country_codes" ]]\
		|| cache_country_codes &
	exec {dump_stream}<> <(curl -s "${MIRRORGEN_URL}all/https/")
	fifo_read_through ${dump_stream} "^## Worldwide"
	while read -t 0 -u ${dump_stream} && read -u ${dump_stream}; do
		[[ "$REPLY" != '##'* ]]\
			&& continue
		[[ "${REPLY#* }" == T$'\xC3\xBC'rkiye ]]\
			&& printf 'Turkey'\
			|| printf '%s\n' "${REPLY#* }"
	done
	exec {dump_stream}>&-
}

fetch_devices()
{
	for dev in /sys/block/{sd,hd,nvme,mmcblk}*;{
		printf '/dev/%s \xF7 ' ${dev##*/}
		: $(($(<"$dev/size") * 5120>>30))
		printf '%s.%cGib\n' ${_:: -1} ${_: -1}
	}
}

process_config()
{
	local -l optkey
	local -- optvals filename
	local -- opt_cond=" ${LIG_OPT[*]::$(( ${#LIG_OPT[@]} - 3 ))} "
	if [[ -f "${LIG_CACHE}/options.conf" ]]; then : "${LIG_CACHE}/options.conf"
	elif [[ -f "${LIG_SRCDIR}/options.conf" ]]; then : "${LIG_SRCDIR}/options.conf"
	else return; fi; filename="$_"
	while read optkey; do case "$optkey" in
	'[options]')
		while IFS=$' \t\n=' read optkey optvals && [[ -n "$optkey" ]]; do
			[[ "${opt_cond}" =~ " $optkey " ]]\
				|| die "Bad config key: $optkey"
			:
		done;;
	'[mirrors]')
		:
		;;
	'[packages]')
		:
		;;
	esac; done < "$filename"
}


get_console_size()
{
	((OPT_TEST)) || read -r LINES COLUMNS < <(stty size)
	TRANSVERSE='(LINES+1)>>1'
	SAGITTAL='(COLUMNS+1)>>1'
	((${#window_stack[@]})) && {
		: "${window_stack[0]%:*:*}"
		window_stack[0]="main_keylist:1:1:${window_stack[0]/$_/$LINES:$COLUMNS}"
		for ((i=0;++i<${#window_stack[@]};));{ :;}
	}
}

get_key()
{
	local -n ref=$1
	for((;;)){
		read ${READ_OPTS[@]} -N1 ref
		# Handling timeouts
		(($?>128))\
			&& continue
		# Handling escape and CSI characters
		[[ $ref == $'\x1B' ]] && {
			read ${READ_OPTS[@]} -N1
			[[ "${REPLY}" != "[" ]]\
				&& return
			read ${READ_OPTS[@]} -N2
			ref=$'\x9B'${REPLY}
		}
		return
	}
}

get_mirrorlist()
{
	local -n ref="$1"
	mkdir "${LIG_TMPDIR}/mirrors"
	exec {fd_mirrors}<> <(curl -s ${MIRROR_URL})
	fifo_read_through ${fd_mirrors} "^## Worldwide"
	fifo_read_through ${fd_mirrors} ''
	while read -t 0 -u ${fd_mirrors} && read -u ${fd_mirrors}; do
		case "$REPLY" in
		'##'*) ref+=("${REPLY#* }");;
		'#'*) printf "${REPLY#\#}\n" >> "${LIG_TMPDIR}/mirrors/${arr[-1]}";;
		esac
	done
	exec {fd_mirrors}>&-
}

get_wintype()
{
	[[ $(type -t "${1:?}") == function ]] && {
		printf %s 'function'
	} || {
		local -n ref="${1}_wintype"
		[[ -v "${!ref}" ]]\
			&& printf %s "$ref"\
			|| die
	}
}

install()
{
	:
}

nap()
{
	[[ -n "${fd_nap:-}" ]]\
		|| exec {fd_nap}<> <(:)
	read -t ${1:-0.001} -u ${fd_nap}\
		|| :
}

print_pg()
{
  local i y x m n lim offs
  local -n w ref
  local white_sp
  w=win_ctx; ref=${w[nref]}; offs=${w[offset]}
  read -d '' y x m n <<< "${w[attr]//,/ }"
  ((m-=2,n-=2))
  ((lim=offs+m<${#ref[@]}?offs+m:${#ref[@]}))
  wipe_window
  # Populate page
  case ${w[pg_type]} in
    'single')
        for((i=offs-1;++i<lim;)){ printf '\x1B7  %s\x1B8\x9BB' "${ref[$i]}";}
        printf '\x9B%sA\x1B7  ' $((i-=w[idx]))
        : "${ref[$((lim-i))]}"
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

push_window()
{
	[[ $(get_wintype $1) != form ]] && {
		((${#window_stack[@]})) && {
			local -n ref=${1}_strs
			local -i lines="${#ref[@]} < LINES - 4 ? ${#ref[@]} + 2 : LINES - 2"
			local -i columns='SAGITTAL - 1'
			window_stack[-1]="${window_stack[-1]%:*:*}:$pg_idx:$pg_off"
			window_stack+=("${1}:2:${SAGITTAL}:${lines}:${columns}:0:0")
		} || {
			window_stack=("main_keylist:1:1:${LINES}:${COLUMNS}:0:0")
		}
	} || {
		:
	}
	update_pg_info
	draw_window
}

setup_console()
{
	stty -g > "${LIG_TMPDIR}/.stty"
	stty -echo -icanon -ixon isig susp undef
	# Select default (single byte character set)
	printf '\x1B%s' '%@'
	# 2J    Clear screen
	# 31m   Foreground red
	# ?25l  Hide cursor
	# ?7l   Disable line wrapping
	printf '\x9B%s' 2J 31m ?25l ?7l
}

setup_references()
{
	local opt
	for opt in keymap locale timezone;{
		add_option_key $opt single_select
	}
	add_option_key mirrors multi_select
	add_option_key hostname form
	add_option_key username form
	add_option_key block_device single_select
	main_keylist_wintype=single_select
	keymap_strs=($(localectl list-keymaps))
	timezone_strs=($(timedatectl list-timezones))
	IFS=$'\n' read -d '' -a locale_strs < "/usr/share/i18n/SUPPORTED"
	get_mirrorlist mirrors_strs
	for opt in /sys/block/{sd,hd,nvme,mmcblk}*;{
		: $(($(<"$opt/size") * 5120>>30))
		: "/dev/${opt##*/} "$'\xF7'" ${_:: -1}.${_: -1}Gib"
		block_device_strs+=("$_")
	}
	for ((i=-1;++i<${#main_keylist_strs[@]};));{
		printf -v main_keylist_strs[$i] '%-*sunset' $opt_pad ${main_keylist_strs[$i]}
	}
	add_function_key save_config
	add_function_key load_config
	add_function_key install
}

test_size() {
  # Temp vars as invoking stty overrides values for LINES and COLUMNS
  local -a dim
  OPT_TEST=1
  read -ra dim -p 'Enter display size in {LINES} {COLUMNS} (ex: 25 80): '
 setup_console 
  !((${dim[0]})) || !((${dim[1]})) && die 'Parse Error'
  LINES=${dim[0]}; COLUMNS=${dim[1]}
  return 0
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
      str="${win_ctx[nref]}"
      ((i=${win_ctx[idx]}))
      printf '%s\x9B7m' "${str::${idx}}"
      ((idx==${#str})) && printf ' \x1B8' ||
        printf '%s\x9B27m%s\x1B8' "${str:${idx}:1}" "${str:$((idx+1))}"
    ;;
  esac
}

handle_event_enter()
{
	[[ ${pg_ref} == main_keylist ]] && {
		: "$(get_wintype ${main_keylist[${pg_idx}]})"
		case $_ in
		*'_select')
			push_window
			update_pg_info
			print_pg
		;;
		esac
	}
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
            ((!idx)) && {
              [[ "${key}" =~ [a-z0-9] ]] || {
                prompt 'err' 'VALID 1ST CHARACTERS: [a-z,0-9]'; continue;}
            } || {
              [[ "${key}" =~ [a-z0-9-] ]] || {
              prompt 'err' 'VALID CHARACTERS: [a-z,0-9,-]'; continue;}
	    }
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

loop_ui()
{
	local -- key
	print_pg
	for((;;)){
		get_key key
		case $key in
		'q' |\
		$'\x1B') # ESC
			[[ ${pg_ref} == main_keylist ]]\
				&& exit_prompt\
				|| return 0
		;;
		$'\x0A') # ENTER
			handle_event_enter
		;;
		'k' |\
		$'\x9BA') # UP
			((!pg_idx)) &&
				continue
			((pg_idx == pg_off)) && {
				((pg_off--))
				((pg_idx--))
				print_pg
				continue
			}
		;;
		'j' |\
		$'\x9BB') # DOWN
			((pg_idx + 1 == pg_arr_len)) && continue
			((pg_idx + 1 == pg_off + pg_lines)) && {
				((pg_off++))
				((pg_idx++))
				print_pg
				continue
			}
		;;
		$'\x02' |\ # CTRL+B
		$'\x9B5~') # PG_UP
			pg_off='pg_off - pg_lines > 0 ? pg_off - pg_lines : 0'
			pg_idx='pg_idx - pg_lines > 0 ? pg_idx - pg_lines : 0'
		;;&
		$'\x15') # HALF_PG_UP(CTRL+U)
			pg_idx='pg_idx - pg_stop > 0 ? pg_idx - pg_stop : 0'
			((pg_idx < pg_off))\
				&& pg_off=pg_idx
		;;&
		$'\x06' |\ # CTRL+F
		$'\x9B6~') # PG_DOWN
			((pg_off + pg_lines < pg_arr_len - pg_lines))\
				&& pg_off+=pg_lines\
				|| pg_off='pg_arr_len > pg_lines ? pg_arr_len - pg_lines : 0'
			pg_idx='pg_idx + pg_lines < pg_arr_len ? pg_idx + pg_lines : pg_arr_len - 1'
		;;&
		$'\x04') # HALF_PG_DOWN(CTRL+D)
			pg_idx='pg_idx + pg_stop < pg_arr_len ? pg_idx + pg_stop : pg_arr_len - 1'
			((pg_idx + 1 > pg_off + pg_lines))\
				&& pg_off='pg_idx - pg_lines + 1'
		;;&
		$'\x9B1~') # HOME
			pg_off=0
			pg_idx=0
		;;&
		$'\x9B4~') # END
			pg_off='pg_arr_len > pg_lines ? pg_arr_len - pg_lines : 0'
			pg_idx='pg_arr_len - 1'
		;;&
		$'\x02'|$'\x04'|$'\x06'|$'\x15'|$'\x9B1~'|$'\x9B4~'|$'\x9B5~'|$'\x9B6~')
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
      q|$'\x1B') return 0;; # ESC
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

save_config()
{
	:
}

load_config()
{
	:
}

update_pg_info()
{
	local -n stack_ref
	local -- lines cols
	read -d '' stack_ref _ _ lines cols pg_idx pg_off <<<"${window_stack[-1]//:/ }"
	pg_ref="${!stack_ref}"
	pg_arr_len=${#stack_ref[@]}
	pg_lines='lines - 2'
	pg_cols='cols - 2'
	pg_stop='pg_lines>>1'
}

wipe_window()
{
	local blanks y x lines columns
	read -d '' _ y x lines columns _ _ <<< "${WINDOW_STACK[-1]//:/ }"
	((lines-=2))
	((columns-=2))
	printf -v blanks '%*s' $((lines > columns ? lines : columns)) ''
	: "${blanks::$lines}"
	: "${_// /$'\x1B7'${blanks::$columns}$'\x1B8\x9BA'}"
	printf '\x9B%s;%sH%s\x1B8' $((y + lines)) $((x + 1)) "$_"
}

main "$@"
