#!/usr/bin/env bash
####################################################################
#
# giomplay.sh: A function to initiate default play, in a
# minimal menu setting, for use in a mobile phone setting, for example
#
####################################################################
function play_default {
RESULTLIMIT=$SELECTIONS
MAXLOOPS=0; PLAYS=1

# Construct a SQL statement, execute it and return a result via the searchfilter.txt file
source "$CONFDIR/bin/giodefsrch.sh"

MAXLOOPS=$(cat "$CONFDIR/txt/searchfilter.txt" | wc -l)
SELECTIONS=$MAXLOOPS

if [[ $MAXLOOPS -eq 0 ]]; then
  tput cup 13 4; tput setaf "$ALERT"; echo -en "Nothing selected to play!"
  tput cup 14 4; tput setaf "$ALERT"; read -p "Press a key to continue."
fi
while [[ $PLAYS -le $MAXLOOPS ]]; do 
  TOTALDUR=0; duration=0
  PLAYDIR=$($SEDPROG "${PLAYS}q;d" "$CONFDIR/txt/searchfilter.txt" 2>/dev/null); DIRBASE="$PLAYDIR"
  compute_duration
  clearscreen
  if [[ -f  $CONFDIR/txt/autostop.txt ]]; then
    PLAYS=$((MAXLOOPS+1))
    rm -f "$CONFDIR/txt/autostop.txt" >/dev/null 2>&1
    rm -rf "$CONFDIR/txt/searchfilter.txt" 2>/dev/null
    break
  fi

  if [[ -f  $CONFDIR/txt/terminate.txt ]]; then
    PLAYS=$((MAXLOOPS+1))
    rm -f "$CONFDIR/txt/terminate.txt" >/dev/null 2>&1
    rm -rf "$CONFDIR/txt/searchfilter.txt" 2>/dev/null
    break
  fi

  if [[ -f  $CONFDIR/txt/skip.txt ]]; then
    rm -f "$CONFDIR/txt/skip.txt" >/dev/null 2>&1
  fi
    
  if [[ $(uname -a) == *"Darwin"* ]]; then 
    echo -ne "\033]0; $TERMTITLE \007"
  else
    echo -en "\033]0; $TERMTITLE \007\c"
  fi
  play_music
  ((PLAYS++))

  if [[ -f  $CONFDIR/txt/repeat.txt ]]; then
    rm -f "$CONFDIR/txt/repeat.txt"; PLAYS=$((PLAYS-1))
  fi
done
rm -rf "$CONFDIR/txt/searchfilter.txt" 2>/dev/null
}

play_default
if [[ $(uname -a) == *"Darwin"* ]]; then 
  echo -ne "\033]0; Giocoso \007"
else
  echo -en "\033]0; Giocoso \007\c"
fi