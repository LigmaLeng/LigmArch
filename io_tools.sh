#!/usr/bin/env/ bash


trap 'die "Interrupted"' SIGINT SIGHUP SIGTERM
_set_tty() {
    stty_bak=$( stty -g | tee stty.bak )
    stty -icanon -nl -echo isig
}

_redeem() {
    stty "$stty_bak"
}

die() {
    # Resets screen and cursor
    printf "\e[m\e[;r\e[2J\e[?25h"
    # Output to stderr
    printf "%s: line %d: %s: %s.\n" ${BASH_SOURCE[1]} ${BASH_LINENO[0]} ${FUNCNAME[1]} ${1-Died} >&2
    exit 1
}

read -r LINES COLUMNS < <(stty size)
declare -A _OPTS=(
[keymap]="us"
[partition_type]="linux-lvm"
[kernel]="linux-lts"
[network]="network-manager"
[locale]="en-AU"
[username]=""
[hostname]=""
[rootpass]=""
[userpass]=""
)


################################################
# Macros
################################################


# Generate a positive random integer
# from ranges 1 to arg1 (inclusive)
#
_roll_d() {
    printf "$(( ( RANDOM % $1 ) + 1 ))"
}

# Converts 2D index for Linear access to arrays
#
# Requires 3 arguments
# arg1:		column index
# arg2:		row index
# arg3:		leading dimension
#
_unroll_idx() {
    local i=$1
    local j=$2
    local ld=$3
    printf "$(( j * ld + i ))"
}

################################################


################################################
# Display variables
################################################

#_CARD_BUF=( $(for (( i = 0; i <  ))) )

_TL="\u2554"	# Top-Left corner ╔
_TR="\u2557" 	# Top-Right corner ╗
_BL="\u255A" 	# Bottom-Left corner ╚
_BR="\u255D" 	# Bottom-Right corner ╝
_HB="\u2550" 	# Horizontal border ═
_VB="\u2551" 	# Vertical border ║

# Array of glyphs representing the gradient of
# grayscale intensity in descending order
# ▒░#≡*•○·
_GRAD=(
    "\u2592"
    "\u2591"
    "#"
    "\u2261"
    "*"
    "\u2022"
    "\u25CB"
    "\u00B7"
)

################################################


# Function to repeat given string n number of times
# Does not include newline escape
#
# Accepts 2 arguments
# arg1:    n number of repeats (required)
# arg2:    target string to repeat (optional; default = "-")
#
repeat() {
    local tmpl="${2:--}"
    local str=""
    for (( i = 0; i < $1 ; i++ )); do str+=$tmpl; done
    printf "$str"
}


_draw_frame() {
    local canvas_w=$(( ${1:-COLUMNS} - 2 ))
    local canvas_h=$(( ${2:-LINES} - 2 ))

    printf "\e[31m\u2554$( repeat $canvas_w "\u2550" )\u2557\n"
    for (( i = 0; i < $canvas_h; i++ )); do
        printf "\u2551$( repeat $canvas_w "\u0020" )\u2551\n"
    done
    printf "\u255A$( repeat $canvas_w "\u2550" )\u255D\e[m\n\e[2;2H"

}


nap() {
    local IFS # Reset IFS
    [[ -n "${_nap_fd:-}" ]] || { exec {_nap_fd}<> <(:); } 2>/dev/null
    read ${1:+-t "$1"} -u $_nap_fd || :
}

dive() {
    local char
    local sp
    local str

    while read -sN1 char; do
        ((0x1B == char)) && echo "esc"
        case $char in
            $'\x7F'|$'\x08') [ -z "$str" ] && str=${str:0:-1};;
            $'\n') echo "ent";;
            ' ') echo "spaco";;
        esac
    done
}
#dive
stty -a
