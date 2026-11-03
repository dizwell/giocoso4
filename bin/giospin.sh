#!/usr/bin/env bash
####################################################################
#
# giospin: routine for displaying a timer/work-in-progress
# spinner, displaying variable messages
#
# Spinners taken from:
# https://github.com/sindresorhus/cli-spinners
#
####################################################################
function spinner {
tput civis
spin=()
pid=$!    # Process Id of the previous running command
spin[0]="◐";spin[1]="◓";spin[2]="◑";spin[3]="◒"
MSGLENGTH=${#MESSAGE}
tput cup 25 4; echo -en "                                                                                               "
tput cup 25 4; tput setaf $INFOTEXT; echo -en "$MESSAGE"; tput setaf $SPINNER; 
while kill -0 $pid 2>/dev/null;
do
  for i in "${spin[@]}"
  do
    tput cup 25 $((MSGLENGTH+6)); echo -ne "$i"
    sleep .1
  done
done
tput cvvis
}