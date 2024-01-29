#!/bin/bash
#
# TODO: Write file header

########################################
#(INSERT FUNCTION DESCRIPTON)
#Globals:
#  (DELETE INCLUDING DECLARATION IF NONE)
#  eg:
#  BACKUP_DIR
#  SOMEDIR
#Arguments:
#  None
#Outputs:
#  (DELETE INCLUDING DECLARATION IF NONE)
#  eg: Writes location to stdout
#Returns:
#  (DELETE INCLUDING DECLARATION IF NONE)
#  eg: 0 if thing was deleted, non-zero on error
########################################
#readonly LIG_CACHE_DIR="${XDG_CACHE_HOME:=${HOME}/.cache}"
declare -i LINES COLUMNS
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

trap 'die "Interrupted"' SIGINT SIGTERM

get_size() {
  read -r LINES COLUMNS < <(stty size)
}

mod_stty() {
  readonly STTY_BAK=$(stty -g)
  stty -nl -echo -icanon -ixon isig 
}

reset_stty() {
  stty $STTY_BAK
}

cleanup_display() {
  printf "\e[m\e[;r\e[2J\e[?25h"
}

nap() {
  local IFS # Reset IFS
  [[ -n "${_nap_fd:-}" ]] || { exec {_nap_fd}<> <(:); } 2>/dev/null
  read ${1:+-t "$1"} -u $_nap_fd || :
}

part_display() {
  local -i lines_odd=$(( LINES & 1 ))
  local -i lines_mid=$(( (LINES + 1) >> 1 ))
  local -i cols_odd=$(( COLUMNS & 1 ))
  local -i cols_mid=$(( (COLUMNS + 1) >> 1 ))
  (($lines_odd)) && glyph="\xE2\x95\x90" \
    || glyph="\xE2\x94\x80\x1B\x9BB\x1B\x9BD\xE2\x94\x80"

  for (( i = 0; i < cols_mid - 1; i++ )); do
    printf "\x1B\x9B${lines_mid};$(( cols_mid - i))H${glyph}"
    printf "\x1B\x9B${lines_mid};$(( cols_mid + i + !cols_odd))H${glyph}"
    nap 0.003
  done
}

prompt_exit() {
  part_display
}
die() {
  # Output to stderr
  printf "%s: line %d: %s: %s.\n" ${BASH_SOURCE[1]} ${BASH_LINENO[0]} ${FUNCNAME[1]} ${1-Died} >&2
  cleanup_display
  exit 1
}

#≡ = \xe2\x89\xa1
#║ = \xe2\x95\x91
#═ = \xe2\x95\x90
#╝ = \xe2\x95\x9d
#╚ = \xe2\x95\x9a
#╗ = \xe2\x95\x97
#╔ = \xe2\x95\x94

repeat() {
  local tmpl="${2:--}"
  local str=""
  for (( i = 0; i < $1 ; i++ )); do str+=$tmpl; done
  printf "$str"
}

draw_frame() {
  local canvas_w=$(( ${1:-COLUMNS} - 2 ))
  local canvas_h=$(( ${2:-LINES} - 2 ))

  printf "\x1B\x9B2J\x1B\x9B;H\x1B\x9B31m"
  printf "\xE2\x95\x94$( repeat $canvas_w "\xE2\x95\x90" )\xE2\x95\x97\n"
  for (( i = 2; i < LINES; i++ )); do
    printf "\xE2\x95\x91\x1B\x9B${i};${COLUMNS}H\xE2\x95\x91\n"
  done
  printf "\xe2\x95\x9a$( repeat $canvas_w "\xe2\x95\x90" )\xe2\x95\x9d"
  printf "\x1b\x9b2;2H"
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

    #    # Control codes if interested
    #    # 127   (\0x7B)    Backspace
    #    # 8     (\0x08)    Alternative backspace
    #    # 27    (\0x33)    ESC
    #    if [[ $sp == 127 || $sp == 8 && ${#str} > 0 ]]; then
    #        str=${str:0:-1} # Strip last char
    #    elif [[ "$sp" = "27" ]]; then
    #        # Because ESC is read in one byte
    #        # Detecting control sequence indicators ('[' + sequence)
    #        # is broken down into multiple steps
    #        read -sn1 sp
    #        [ "$sp" != "[" ] && die
    #        read -sn1 sp
    #        case "$sp" in
    #            A) echo "up";;
    #            B) echo "down";;
    #            C) echo "right";;
    #            D) echo "left";;
    #            *) exit 0;;
    #        esac
    #    else
    #        str=$str"$char"
    #    fi
    #    clear
	  #  _draw_frame 160 44
    #    echo "Search: $str"
    #    grep -im 10 "$str" lc.txt
    #done
}
main() {
  mod_stty

  trap 'get_size; draw_frame' SIGWINCH
  get_size
  #hide curs
  printf "\x1B\x9B?25l"
  draw_frame
  part_display
  nap 2
  reset_stty
#part_display
#dive
}
main "$@"
