#!/usr/bin/env bash
####################################################################
#
# gioplay.sh: A function to initiate various play modes
#
####################################################################
function play_default {
RESULTLIMIT=$SELECTIONS
MAXLOOPS=0; PLAYS=1

# Construct a SQL statement, execute it and return a result via the searchfilter.txt file
source "$CONFDIR/bin/giodefsrch.sh"

MAXLOOPS=$(cat "$CONFDIR/txt/searchfilter.txt" | wc -l)
LINESELECTIONS=$MAXLOOPS

if [[ $MAXLOOPS -eq 0 ]]; then
  dialog --stdout --backtitle "Giocoso Music Search Failure" --title " No Matching Results " --msgbox "\nNo music can be found to match your default selection criteria.\n\nCheck the '$CONFDIR/tmp/folders-to-be-played.txt' file to see if that helps you work out why this might be, or consider editing your configuration parameters to relax various selection criteria and then try again." 12 80
fi

while [[ $PLAYS -le $MAXLOOPS ]]; do 
  TOTALDUR=0; duration=0
  PLAYDIR=$($SEDPROG "${PLAYS}q;d" "$CONFDIR/txt/searchfilter.txt" 2>/dev/null); DIRBASE="$PLAYDIR"
  compute_duration    
  clearscreen
  if [[ -f  $CONFDIR/txt/autostop.txt ]]; then
    PLAYS=$((MAXLOOPS+1))
    rm -f "$CONFDIR/txt/autostop.txt" >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
    rm -rf "$CONFDIR/txt/searchfilter.txt" 2>/dev/null
    break
  fi

  if [[ -f  $CONFDIR/txt/terminate.txt ]]; then
    PLAYS=$((MAXLOOPS+1))
    rm -f "$CONFDIR/txt/terminate.txt" >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
    rm -rf "$CONFDIR/txt/searchfilter.txt" 2>/dev/null
    break
  fi

  if [[ -f  $CONFDIR/txt/skip.txt ]]; then
    rm -f "$CONFDIR/txt/skip.txt" >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
  fi

  clear; source "$CONFDIR/bin/giomenudraw.sh" playing
  if [[ $(uname -a) == *"Darwin"* ]]; then 
    echo -ne "\033]0; Now playing: $TERMTITLE \007"
  else
    echo -en "\033]0; Now playing: $TERMTITLE \007\c"
  fi
  play_music
  ((PLAYS++))

  if [[ -f  $CONFDIR/txt/repeat.txt ]]; then
    rm -f "$CONFDIR/txt/repeat.txt"; PLAYS=$((PLAYS-1))
  fi
done
rm -rf "$CONFDIR/txt/searchfilter.txt" 2>/dev/null
}

function play_filter {
LINENUM=1; PLAYS=1; DIRECT_PLAY=0; LINESELECTIONS=0; RECORDPLAY=0; tput civis
source "$CONFDIR/bin/giofilter.sh"                               # Invokes the user-input screen for selections to be made

if [[ $FILTERCANCELLED -eq 1 ]]; then return; fi
LINESELECTIONS=$(cat "$CONFDIR/txt/searchfilter.txt" | wc -l)
if [[ $LINESELECTIONS -eq 0 ]]; then
  dialog --stdout --backtitle "Giocoso Music Search Failure" --title " No Matching Results " --msgbox "\nNo music can be found to match the selection criteria specified by your choice of filters. \n\nMaybe relax or re-think your various selection filters before trying again." 10 80
  SEARCHCOUNT=0                                                       # Re-set the search count, in case they want to try again
  PLAYS=$((LINESELECTIONS+1))                                             # Force this while loop to terminate (and thus return to the main menu)
fi

while [[ $PLAYS -le $LINESELECTIONS ]]; do
  TOTALDUR=0; duration=0
  PLAYDIR=$($SEDPROG "${LINENUM}q;d" "$CONFDIR/txt/searchfilter.txt" 2>/dev/null); DIRBASE="$PLAYDIR"
  compute_duration; clearscreen;
  if [[ -f  $CONFDIR/txt/autostop.txt ]]; then
    PLAYS=$((LINESELECTIONS+1))
    rm -f "$CONFDIR/txt/autostop.txt" >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
    break
  fi

  if [[ -f  $CONFDIR/txt/terminate.txt ]]; then
    PLAYS=$((LINESELECTIONS+1))
    rm -f "$CONFDIR/txt/terminate.txt" >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
    break
  fi

  clear; source "$CONFDIR/bin/giomenudraw.sh" playing;
  if [[ $(uname -a) == *"Darwin"* ]]; then 
    echo -ne "\033]0; Now playing: $TERMTITLE \007"
  else
    echo -en "\033]0; Now playing: $TERMTITLE \007\c"
  fi
  play_music
  ((PLAYS++))
  if [[ -f  $CONFDIR/txt/repeat.txt ]]; then rm -f "$CONFDIR/txt/repeat.txt"; PLAYS=$((PLAYS-1)); else LINENUM=$((LINENUM+1)); fi
  rm -f "$CONFDIR/txt/skip.txt" >/dev/null 2>&1
done

rm -f "$CONFDIR/txt/searchfilter.txt" 2>/dev/null
echo -en "\033]0; Giocoso \007\c"                			 # Re-setting terminal's titlebar to indicate nothing's playing
INVALIDFLAC=0                                              # Re-setting bad FLAC indicators, so fresh play attempts won't immediately fail
}

function play_sql {
LINENUM=1; PLAYS=1; DIRECT_PLAY=0; tput civis
source "$CONFDIR/bin/gioadvsql.sh"
LINESELECTIONS=$(cat "$CONFDIR/txt/searchfilter.txt" | wc -l)

if [[ $LINESELECTIONS -eq 0 ]]; then
  dialog --stdout --backtitle "Giocoso Music Search Failure" --title " No Matching Results " --msgbox "\nNo music can be found to match your supplied SQL statement. \n\nCheck your SQL syntax and the aggregate effect of your choice of combined selection tests before trying again." 10 80
  SEARCHCOUNT=0                                                       # Re-set the search count, in case they want to try again
  PLAYS=$((LINESELECTIONS+1))                                             # Force this while loop to terminate (and thus return to the main menu)
fi

while [[ $PLAYS -le $LINESELECTIONS ]]; do
  TOTALDUR=0; duration=0
  PLAYDIR=$($SEDPROG "${LINENUM}q;d" "$CONFDIR/txt/searchfilter.txt" 2>/dev/null); DIRBASE="$PLAYDIR"
  compute_duration; clearscreen;
  if [[ -f  $CONFDIR/txt/autostop.txt ]]; then
    PLAYS=$((LINESELECTIONS+1))
    rm -f "$CONFDIR/txt/autostop.txt" >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
    break
  fi

  if [[ -f  $CONFDIR/txt/terminate.txt ]]; then
    PLAYS=$((LINESELECTIONS+1))
    rm -f "$CONFDIR/txt/terminate.txt" >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
    break
  fi

  clear; source "$CONFDIR/bin/giomenudraw.sh" playing;
  if [[ $(uname -a) == *"Darwin"* ]]; then 
    echo -ne "\033]0; Now playing: $TERMTITLE \007"
  else
    echo -en "\033]0; Now playing: $TERMTITLE \007\c"
  fi
  play_music
  ((PLAYS++))
  if [[ -f  $CONFDIR/txt/repeat.txt ]]; then rm -f "$CONFDIR/txt/repeat.txt"; PLAYS=$((PLAYS-1)); else LINENUM=$((LINENUM+1)); fi
  rm -f "$CONFDIR/txt/skip.txt" >/dev/null 2>&1
done

rm -f "$CONFDIR/txt/searchfilter.txt" 2>/dev/null
echo -en "\033]0; Giocoso \007\c"                					       # Re-setting terminal's titlebar to indicate nothing's playing
INVALIDFLAC=0                                              # Re-setting bad FLAC indicators, so fresh play attempts won't immediately fail
}

function play_direct {
PLAYS=1; LINESELECTIONS=1; DIRECT_PLAY=0; unset SEARCHSQL; tput civis
while [[ $PLAYS -le $LINESELECTIONS ]]; do
  TOTALDUR=0; duration=0
  if [[ -f  $CONFDIR/txt/repeat.txt ]]; then rm -f "$CONFDIR/txt/repeat.txt"; fi
  source "$CONFDIR/bin/giodirselect.sh"
  exitStatus=$?; if [[ $exitStatus -eq 99 ]]; then break; fi		# Status is 99 if they press ESC or Cancel on the dialog, so leave the loop and return to the menu
  PLAYDIR=$($SEDPROG "1q;d" "$CONFDIR/txt/directplay.txt" 2>/dev/null); DIRBASE="$PLAYDIR"; rm -f "$CONFDIR/txt/directplay.txt" >/dev/null 2>&1
  compute_duration
  clearscreen

  clear; source "$CONFDIR/bin/giomenudraw.sh" playing
  if [[ $(uname -a) == *"Darwin"* ]]; then 
    echo -ne "\033]0; Now playing: $TERMTITLE \007"
  else
    echo -en "\033]0; Now playing: $TERMTITLE \007\c"
  fi
  play_music

  rm -f "$CONFDIR/txt/skip.txt" >/dev/null 2>&1

  # Autostop, Terminate and Pause (which works by creating terminate.txt) all mean "don't go on to
  # another recording". They must be checked here, after the play, so the folder selector isn't
  # shown again before they take effect.
  if [[ -f  $CONFDIR/txt/autostop.txt ]]; then
    rm -f "$CONFDIR/txt/autostop.txt" >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
    break
  fi

  if [[ -f  $CONFDIR/txt/terminate.txt ]]; then
    rm -f "$CONFDIR/txt/terminate.txt" >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
    break
  fi
done
echo -en "\033]0; Giocoso \007\c"                       # Re-setting terminal's titlebar to indicate nothing's playing
INVALIDFLAC=0                                           # Re-setting bad FLAC indicators, so fresh play attempts won't immediately fail
}

function play_playlist {
LINENUM=1; PLAYS=1; DIRECT_PLAY=0; LINESELECTIONS=0; tput civis
source "$CONFDIR/bin/gioplaylist.sh" || return

# Now iterate through the playlist and make sure the same folders that existed when it was created
# still exist and all continue to contain valid FLACs.
unset VALIDDIRS; FOLDERCOUNT=1; MAXFOLDER=$(cat "$playlist_name" | wc -l)
while IFS= read -r FOLDER; do
  tput civis; tput cup 25 4; echo -e "Checking candidate folders... $FOLDERCOUNT / $MAXFOLDER"
  if [[ -z $FOLDER ]]; then
    :
  elif [[ ! -d $FOLDER ]]; then
    :
  else
    # There is a result, it exists on disk... does it contain flacs?
    cd "$FOLDER" 2>/dev/null
    COUNTFLAC=$(ls *.flac 2>/dev/null | wc -l)
    if [[ $COUNTFLAC -eq 0 ]]; then
      :
    else
      VALIDDIRS="$VALIDDIRS"$'\n'"$FOLDER"
      ((LINESELECTIONS++))
    fi
  fi
((FOLDERCOUNT++))
done <<< "$(cat $playlist_name)"

echo "$VALIDDIRS" > "$CONFDIR/txt/searchfilter.txt"
$SEDPROG -i '/^[[:space:]]*$/d' "$CONFDIR/txt/searchfilter.txt" 2>/dev/null      # Remove blank line from top of file list, should there be one
$SEDPROG -i '/concat(/d' "$CONFDIR/txt/searchfilter.txt" 2>/dev/null             # Remove query from top of file list, should it get into there

if [[ $LINESELECTIONS -eq 0 ]]; then
  dialog --stdout --backtitle "Giocoso Music Search Failure" --title " No Matching Results " --msgbox "\nYour playlist doesn't appear to match any music files. \n\nConfirm your music folder locations and maybe edit or re-create the playlist before trying again." 10 80
  SEARCHCOUNT=0                                                       # Re-set the search count, in case they want to try again
  PLAYS=$((LINESELECTIONS+1))                                             # Force this while loop to terminate (and thus return to the main menu)
fi

while [[ $PLAYS -le $LINESELECTIONS ]]; do
  PLAYDIR=$($SEDPROG "${LINENUM}q;d" "$CONFDIR/txt/searchfilter.txt" 2>/dev/null); DIRBASE="$PLAYDIR"
  TOTALDUR=0; duration=0
  compute_duration; clearscreen;
  if [[ -f  $CONFDIR/txt/autostop.txt ]]; then
    PLAYS=$((LINESELECTIONS+1))
    rm -f "$CONFDIR/txt/autostop.txt" >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
    break
  fi

  if [[ -f  $CONFDIR/txt/terminate.txt ]]; then
    PLAYS=$((LINESELECTIONS+1))
    rm -f "$CONFDIR/txt/terminate.txt" >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
    break
  fi

  clear; source "$CONFDIR/bin/giomenudraw.sh" playing;
  if [[ $(uname -a) == *"Darwin"* ]]; then 
    echo -ne "\033]0; Now playing: $TERMTITLE \007"
  else
    echo -en "\033]0; Now playing: $TERMTITLE \007\c"
  fi
  play_music
  ((PLAYS++))
  ((LINENUM++))
  rm -f "$CONFDIR/txt/skip.txt" >/dev/null 2>&1
done
}

if [[ $1 == default ]]; then play_default; fi
if [[ $1 == direct ]]; then play_direct; fi
if [[ $1 == filter ]]; then play_filter; fi
if [[ $1 == sql ]]; then play_sql; fi
if [[ $1 == playlist ]]; then play_playlist; fi
	
if [[ $(uname -a) == *"Darwin"* ]]; then 
  echo -ne "\033]0;Giocoso: The Classical Music Player\007"
else
  echo -en "\033]0;Giocoso: The Classical Music Player\007\c"						# Setting terminal's titlebar
fi