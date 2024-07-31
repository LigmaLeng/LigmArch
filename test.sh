#!/usr/bin/env bash

usage()
{
	read -d '' <<-EOF
	Usage: bash ${0##*/} [options]

	  Options:
	  -c <config>    Use an alternate config for pre-loading options
	  -a             Restrict drawing characters to ASCII (meant for display bugs)

	  -h             Print this help message
	EOF
	printf %s "$REPLY"
}
[[ -z $1 || $1 == '-h' ]];{
	echo $0
	usage
	exit
}

while getopts ':c:ah' flag; do
	case $flag in
	c) lig_config=$OPTARG;;
	a) :;;
	h) usage; exit;;
	:) die 'option requires an argument';;
	?) die 'invalid option';;
  esac
done

shopt -s nullglob
#readonly LIG_TMPDIR=$(mktemp -d)
cachedir="${XDG_CACHE_HOME:=${HOME}/.cache}/ligmarch"
readonly LIG_OPT=(keymap locale timezone device {host,user}name mirrors packages save install)
readonly MIRRORGEN_URL="https://archlinux.org/mirrorlist/"
#mkdir -p ${cachedir}
#cd ${LIG_TMPDIR}
[[ ${0%/*} == ${0} ]]\
	&& readonly LIG_SRCDIR=${OLDPWD}\
	|| readonly LIG_SRCDIR=${0%/*}

die()
{
	#trap - EXIT
	#cleanup
	: "${BASH_SOURCE[1]}: line ${BASH_LINENO[0]}: ${FUNCNAME[1]}: ${1:-Died}"
	printf '%s\n' "$_">&2
}

chmap_ibm(){ printf '\x1B%%@';}
CSI(){ printf '\x9B%s';}
chmap_utf(){ printf '\x1B%%G';}

setup_console()
{
	trap 'cleanup' EXIT
	setty=$(< stty -g)
	stty -echo -icanon -ixon isig susp undef
	chmap_ibm
	printf '\x9B%s' 2J 31m '?25l' '?7l'
}

cleanup()
{
	printf '\x9B%s' 2J m '?25h' '?7h'
	printf '\x1B%%G'
	[[ -a "${LIG_TMPDIR}/.stty" ]]\
		&& stty $(<"${LIG_TMPDIR}/.stty")
	#[[ -d "${LIG_TMPDIR}" ]]\
		#&& rm -rf "${LIG_TMPDIR}"
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
	done > "${cachedir}/country_codes"
	exec {dom_stream}>&-
}

fetch_mirrorlist()
{
	[[ -f "${cachedir}/country_codes" ]]\
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
	if [[ -f "${cachedir}/options.conf" ]]; then : "${cachedir}/options.conf"
	elif [[ -f "${LIG_SRCDIR}/options.conf" ]]; then : "${LIG_SRCDIR}/options.conf"
	else return; fi; filename="$_"
	while read optkey; do case "$optkey" in
	'[options]')
		while IFS=$' \t\n=' read optkey optvals && [[ -n "$optkey" ]]; do
			[[ "${opt_cond}" =~ " $optkey " ]]\
				|| die "Bad config key: $optkey"

		done;;
	'[mirrors]')
		:
		;;
	'[packages]')
		:
		;;
	esac; done < "$filename"
}

draw_window()
{
	local blanks y x lines columns
	y=1
	x=1
	lines=$LINES
	columns=$COLUMNS
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

nap()
{
	[[ -n "${fd_nap:-}" ]]\
		|| exec {fd_nap}<> <(:)
	read -t ${1:-0.001} -u ${fd_nap}\
		|| :
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


ligmarch()
{
	setup_console
	exit
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
}

