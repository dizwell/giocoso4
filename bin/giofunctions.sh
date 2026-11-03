#!/usr/bin/env bash
# ==============================================================================================================
# giofunctions.sh: Pure Bash functions for use by all other scripts
# ==============================================================================================================

function gbasename {
  # Uses Bash built-in, so no call to external basename utility needed
  local path="${1%/}"
  echo "${path##*/}"    
}

function gdirname {
  # Uses Bash built-in, so no call to external dirname utility needed
  local path="${1%/}"
  echo "${path%/*}"    
}

function round {
echo $(printf %.$2f $(echo "scale=$2;(((10^$2)*$1)+0.5)/(10^$2)" | bc) 2>/dev/null)
}

function erase_logo {
local i                                              # Loop counter only: don't disturb a caller's own i
for i in {0..15}; do
  tput cup $((8 + i)) 52
  printf '%44s' ' '
done
}

function footer_line {
# Builds the control-menu footer line and leaves it in the global FOOTER, ready to be
# printed with:  tput cup 25 4; echo -e "$FOOTER"
#
# Any menu words passed as parameters are shown in reverse video (i.e., "active"), eg:
#    footer_line                    nothing active
#    footer_line Skip               Skip highlighted
#    footer_line Autostop Repeat    both highlighted
#
# The full player offers seven items, minig (DIRECT_PLAY=1) only four. This is the one
# and only place where the wording, the order and the spacing between items are defined.
local gap="     "
local item word sep=""
local -a items
if [[ $DIRECT_PLAY -eq 1 ]]; then
  items=(Autostop Terminate Skip Repeat)
else
  items=(Autostop Terminate Pause Skip Repeat Notes Exit)
fi

FOOTER=""
for item in "${items[@]}"; do
  if [[ " $* " == *" $item "* ]]; then
    word="\033[7m${item}\033[0m"                              # Active: reverse video
  elif [[ $item == "Exit" ]]; then
    word="E\033[93mx\033[0mit"                                # Exit's hotkey is the 'x'
  else
    word="\033[93m${item:0:1}\033[0m${item:1}"                # Everything else: first letter is the hotkey
  fi
  FOOTER+="${sep}${word}"
  sep="$gap"
done
}