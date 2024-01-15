#!/usr/bin/bash

read -r LINES COLUMNS < <(stty size)

################################################
# Macros
################################################

die() {
    printf "%s: line %d: %s: %s.\n" ${BASH_SOURCE[1]} ${BASH_LINENO[0]} ${FUNCNAME[1]} ${1-Died} >&2
    exit 1
}

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
    [[ -n "${_temp_fd:-}" ]] || { exec {_temp_fd}<> <(:); } 2>/dev/null
    read ${1:+-t "$1"} -u $_temp_fd || :
}

dive() {
    local char
    local sp
    local str

    # Read single byte/char from stdin 
    # (expects special characters to be handled downstream)
    while read -sN1 char; do
        # Filter first byte to convert ANSI control codes (if present)
        #     od (output display) flags:
        #         -i    display 16-bit words as signed decimal
        #         -An   don't precede output line with input offset
        #     tr (transform) flags:
        #         -d    delete
        sp=$(echo -n $char | od -i -An | tr -d " ")
        
        # Control codes if interested
        # 127   (\0x7B)    Backspace
        # 8     (\0x08)    Alternative backspace
        # 27    (\0x33)    ESC
        if [[ $sp == 127 || $sp == 8 && ${#str} > 0 ]]; then
            str=${str:0:-1} # Strip last char
        elif [[ "$sp" = "27" ]]; then
            # Because ESC is read in one byte
            # Detecting control sequence indicators ('[' + sequence)
            # is broken down into multiple steps
            read -sn1 sp
            [ "$sp" != "[" ] && die
            read -sn1 sp
            case "$sp" in
                A) echo "up";;
                B) echo "down";;
                C) echo "right";;
                D) echo "left";;
                *) exit 0;;
            esac
        else
            str=$str"$char"
        fi
        clear
	_draw_frame 160 44
        echo "Search: $str"
        grep -im 10 "$str" lc.txt
    done
}
dive
