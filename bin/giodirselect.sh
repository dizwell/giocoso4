#!/usr/bin/env bash
####################################################################
#
# giodirselect: routine for allowing a user to pick a folder
# whose music file content will then be played directly
#
####################################################################
tput cvvis
FLACCOUNT=0; CHOSENFOLDER="$(pwd)"

while [[ $FLACCOUNT -eq 0 ]]; do
  NEWDIR=$(dialog --backtitle "Giocoso Direct Play Mode" --title " Please choose a folder containing one or more FLACs " --dselect "$CHOSENFOLDER" 12 80  3>&1 1>&2 2>&3 3>&- )
  exitStatus=$?
  
  if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then return 99; fi
  if [[ -n $NEWDIR ]]; then 
    NEWDIR="${NEWDIR%/}/"
	FLACCOUNT=$(ls "$NEWDIR"*.flac 2>/dev/null | wc -l)
    if [[ $FLACCOUNT -eq 0 ]]; then
      CHOSENFOLDER="$NEWDIR"
    fi
  fi
done

echo "$NEWDIR" > "$CONFDIR/txt/directplay.txt"
tput civis
sleep .1
