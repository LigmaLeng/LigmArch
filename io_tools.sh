
_FRAME_W=13               # Width
_IMG_H=$(( FRAME_H - 4 )) # Glyph area height
_IMG_W=$(( FRAME_W - 6 )) # Glyph area width
_GLYPH_BASE=42            # Decimal base (0101010) to draw 3 vertical glyphs or manipulate bitwise

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
    printf "$str"
}

_roll_d10() {
    $(( ( RANDOM % 10 ) + 1 ))
}
_pad_bits() {
    printf "%07d\n" $(echo "obase=2;42" | bc)
}
_draw_card() {
    printf "\u2554$( repeat $(( FRAME_W - 2 )) "\u2550" )\u2557\n"
    for (( i = 0; i < FRAME_H - 2; i++ )); do
        printf "\u2551$( repeat $(( FRAME_W - 2 )) "\u0020" )\u2551\n"
    done
    printf "\u255A$( repeat $(( FRAME_W - 2 )) "\u2550" )\u255D\n"
}
