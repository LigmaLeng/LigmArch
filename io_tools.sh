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

# TTY Dims not inscluding final line
_FRAME_H=$(( COLUMNS ))    
_FRAME_W=$(( LINES - 1 ))  

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

_draw_card_buffer() {
    printf "${_TL}$( repeat $(( _FRAME_W - 2 )) "${_HB}" )${_TR}\n"
    for (( i = 0; i < _FRAME_H - 2; i++ )); do
        printf "${_VB}$( repeat $(( _FRAME_W - 2 )) "\u0020" )${_VB}\n"
    done
    printf "${_BL}$( repeat $(( _FRAME_W - 2 )) "${_HB}" )${_BR}\n"
}
nap() {
    local IFS # Reset IFS
    [[ -n "${_temp_fd:-}" ]] || { exec {_temp_fd}<> <(:); } 2>/dev/null
    read ${1:+-t "$1"} -u $_temp_fd || :
}

keyecho() {
    while(1){
        read -rsn1 kbin
            
    }
}
