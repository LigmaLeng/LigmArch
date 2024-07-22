#!/usr/bin/env bash

declare -a global_keylist
declare -i opt_columns

#k|$'\x9BA') # UP/DOWN fallthrough
#[[ ${win_ctx[nref]} == 'setopt_pairs_f' ]] && {
#  ((${#_}>COLUMNS-4)) && {
#    : "${_::$((COLUMNS-6))}${_: -2}"; : "${_%  *} ...${_: -2}";}
#  ((${#ref[$WINDEX]}>COLUMNS-8)) && {
#    : "$_,${ref[$WINDEX]::$((COLUMNS-8))}"
#    : "${_%  *} ..."
#  } || : "$_,${ref[$WINDEX]}" 
#} || : "$_,${ref[$WINDEX]}"
#[[ $_ =~ ^(  .*),(.),(.*)$ ]] && {
#  printf '%s\x1B8\x9B%s\x1B7' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
#  printf '\xAF \x9B7m%s\x1B8' "${BASH_REMATCH[3]}"
#}
#        case ${SETOPT_KEYS[$idx]} in
#          ESP_SIZE|*VOLUME_SIZE|*NAME) seq_ttin $idx;;
#          SAVE*) save_config; printf '\xAF \x9B7m[   SAVED   ]\x1B8';;
#          LOAD*) load_config (($?)) && : 'NO SAVEFILE' || : 'SAVE LOADED' printf '\xAF \x9B7m[%s]\x1B8' "$_"
#          ;;
#          GENERATE) generate_scripts;;
#          *) seq_select $idx;;
#        esac
die()
{
	: "${BASH_SOURCE[1]}: line ${BASH_LINENO[0]}: ${FUNCNAME[1]}: ${1:-Died}"
	printf '%s\n' "$_" >&2
	exit 1
}

add_option_key()
{
	[[ ! $2 =~ ^(single|nested|multi|regex)$ ]] && {
		die
	} || {
		local opt_name="$1"
		declare -g ${opt_name}{_str,_type}
		local -n ref_opt_type=${opt_name}_type
		ref_opt_type="$2"
		global_keylist+=("${opt_name}")
	}
	[[ ${ref_opt_type} == regex ]] && {
		declare -g ${opt_name}{_pattern,_tgt}
	} || {
		declare -ga ${opt_name}_src
		[[ ${ref_opt_type} == multi ]]\
			&& declare -ga ${opt_name}_tgt\
			|| declare -gi ${opt_name}_tgt
	}
	((${#opt_name}>opt_columns-3))\
		&& opt_columns=${#opt_name}+3
}

add_function_key()
{
	[[ $(type -t "$1") != function ]]\
		&& die
	local func_name=$1
	declare -g ${func_name}_str
	local -n str_ref=$_
	: "[${func_name/_/ }]"
	str_ref="${_^^}"
	global_keylist+=("${func_name}")
}

save_config()
{
	echo foo
}

init()
{
	add_option_key keymap single
	add_option_key mirrors multi
	add_function_key save_config
	declare -p
}

streamon_daemon() {
  local infix suffix
  local -a build_policy=( declare -g )
  while read; do
    case ${REPLY//[[:space:]]} in
      '') continue;;
      '['*)
        infix=${REPLY//[\[\]]}
        [[ $infix == VALUE ]] && {
          build_policy=
        }
      ;;
      *) printf '%q\n' "${REPLY}"
    esac
  done < $TEMPLATE_PATH
  #line=${line//=$'\n'/(}
  #line=${line//$'\n'$'\n'/NEWLINE}
}
#ext4_block_size   =
#                    default
#                    1024B
#                    2048B
#                    4096B
#streamon_daemon
init
declare -x LC_ALL=C; shopt -s globstar; :> tdglob; for a in /usr/share/zoneinfo/posix/**;{ [[ -d "$a" ]] || echo "$a" >> tdglob;}
