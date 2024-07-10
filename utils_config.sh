#!/usr/bin/env bash

declare -a MAIN_MENU_KEYLIST
readonly REGEX_POLICY_PATTERN='^(single|nested|multi|pattern)$'

register_option()
{
	local -n ref=${1:?}
	local -- policy=${2:?}
	[[ -v ${!ref} || ! $policy =~ ${REGEX_POLICY_PATTERN} ]] &&
		return 1
	declare -gA ${!ref}
	ref=( [policy]=$policy [src]=${!ref}_src [tgt]=${!ref}_tgt )
	case $policy in
		pattern) :;;
		*) declare -ga ${ref[src]};;&
		single | nested) declare -gi ${ref[tgt]};;
		multi) declare -ga ${ref[tgt]};;
	esac
	MAIN_MENU_KEYLIST+=($1)
}

init()
{
	register_option keymap single
	register_option mirrors multi
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
