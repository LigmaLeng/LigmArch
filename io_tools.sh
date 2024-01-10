_FRAME_H=11               # Width
_FRAME_W=13               # Width
_IMG_H=$(( _FRAME_H - 4 )) # Glyph area height
_IMG_W=$(( _FRAME_W - 6 )) # Glyph area width
_GLYPH_BASE=42            # Decimal base (0101010) to draw 3 vertical glyphs or manipulate bitwise

# Unicode shorthands
_TL="\u2554" # Top-Left corner
_TR="\u2557" # Top-Right corner
_BL="\u255A" # Bottom-Left corner
_BR="\u255D" # Bottom-Right corner
_HB="\u2550" # Horizontal border
_VB="\u2551" # Vertical border

# Function to repeat given string n number of times
#
# Accepts 2 arguments
# arg1:     n number of repeats
# arg2:     target string to repeat
#
# Does not include newline escape

repeat () {
    local n=${1:-80}
    local tgt="${2:--}"
    local str=""
    for (( i = 0; i < $n ; i++ )); do str+=${tgt}; done
    printf "${str}"
}

# Essentially a macro to generate a positive random integer
# 
# Accepts 1 argument:    upper bound (inclusive; defaults to 100)
#

_roll_d() {
    local max=${1:-100}
    printf "$(( ( RANDOM % $max ) + 1 ))"
}

# Helper function to format base10 integer to base2 padded to 7-bits
#
# Accepts 1 argument:    non-negative integer value (max: 127)
#

_pad_bits() {
    local decimal=$1
    printf "%07d\n" $(echo "obase=2;$decimal" | bc)
}
_draw_card() {
    printf "${_TL}$( repeat $(( _FRAME_W - 2 )) "${_HB}" )${_TR}\n"
    for (( i = 0; i < _FRAME_H - 2; i++ )); do
        printf "${_VB}$( repeat $(( _FRAME_W - 2 )) "\u0020" )${_VB}\n"
    done
    printf "${_BL}$( repeat $(( _FRAME_W - 2 )) "${_HB}" )${_BR}\n"
}
_draw_card
