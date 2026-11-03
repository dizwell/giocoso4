#!/usr/bin/env bash
####################################################################
#
# giominifilter: routine for displaying a small form into which
# various music filters are prompted for, permitting minig to do
# non-default plays
#
####################################################################
function prompt_filter {
if ! [[ -d $CONFDIR/tmp ]]; then mkdir -p "$CONFDIR/tmp" 2>/dev/null; fi
FILENAME="$CONFDIR/tmp/musicfilter.txt"

if ! [[ -f $FILENAME ]]; then
  touch "$FILENAME"
fi

dialog --backtitle "Music Selection by Filter" --title " Selection criteria: " --form " " 11 45 0 \
"Composer" 1 1  "" 1 16 20 0 \
"Composition" 2 1  "" 2 16 20 0 \
"Genre" 3 1 "" 3 16 20 0 \
"Unplayed (Y/N)" 4 1 "" 4 16 2 1 \
2>"$CONFDIR/tmp/musicfilter.txt"

if [ $? -eq 0 ]; then
  CANCELLED=0
  readarray -t musicfilter < "$CONFDIR/tmp/musicfilter.txt" 2>/dev/null
else
  CANCELLED=1
fi

if [[ $CANCELLED -eq 0 ]]; then
  ARTLIST="${musicfilter[0]}"
  ALBLIST="${musicfilter[1]}"
  GENRELIST="${musicfilter[2]}"
  UNPLAYEDWRKS="${musicfilter[3]}"

  # If a specific composer was requested, handle it
  # -----------------------------------------------------------------------------
  if [[ ! -z $ARTLIST ]]; then
    ARTLIST=$(echo "$ARTLIST" | $SEDPROG "s/'/\'\'/g" 2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)
    ARTSQL="lower(COMPOSER) like '%${ARTLIST,,}%'"
  else
    ARTSQL="1=1"
  fi

  # If a specific composition was requested, handle it
  # -----------------------------------------------------------------------------
  if [[ ! -z $ALBLIST ]]; then
    ALBLIST=$(echo "$ALBLIST" | $SEDPROG "s/'/\'\'/g" 2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)
    ALBSQL="lower(COMPOSITION) like '%${ALBLIST,,}%'"
  else
    ALBSQL="1=1"
  fi

  # If a specific genre was requested, handle it
  # -----------------------------------------------------------------------------
  if [[ ! -z $GENRELIST ]]; then
    GENRELIST=$(echo "$GENRELIST" | $SEDPROG "s/'/\'\'/g" 2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)
    DISPLAYGENRELIST="$GENRELIST"
    GENRESQL="lower(GENRE) like '%${GENRELIST,,}%'"
  else
    GENRESQL="1=1"
  fi

  if [[ ${UNPLAYEDWRKS,,} == y ]]; then
    UNPLAYEDWORKSQL="rechashvalue not in (select rechashvalue from global_plays)"
  else
    UNPLAYEDWORKSQL="1=1"
  fi

  SQLSTMT="select concat('"$FILEPREFIX"',filesuffix) as DIRNAME from global_recordings where 1=1"
  ORDERSTMT="order by rand()"

  if [[ ! $ARTSQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $ARTSQL"; fi
  if [[ ! $ALBSQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $ALBSQL"; fi
  if [[ ! $GENRESQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $GENRESQL"; fi
  if [[ ! $UNPLAYEDWORKSQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $UNPLAYEDWORKSQL"; fi

  SQLSTMT="$SQLSTMT $ORDERSTMT"
  SQLSTMT="${SQLSTMT/where and/where}"        # Needed to deal with syntactical difficulties when partial combinations of filters are supplied
  SQLSTMT="${SQLSTMT/where  and/where}"       # Needed to deal with syntactical difficulties when partial combinations of filters are supplied

  DIRBASE=$("${PROCONN[@]}" -N -e "$SQLSTMT" 2>/dev/null)

  # The results of the query might contain many candidate folders. We should check all of them exist and contain FLACs before
  # creating a results set that can be played. If folders are non-existent or don't contain FLACs, don't add them to VALIDDIRS.
  # Otherwise, VALIDDIRS becomes our candidate playlist
  unset VALIDDIRS; FOLDERCOUNT=1; MAXFOLDER=$(echo "$DIRBASE" | wc -l)
  while IFS= read -r FOLDER; do
    tput civis; tput cup 25 2; echo -e "Checking candidate folders... $FOLDERCOUNT / $MAXFOLDER"
    if [[ -z $FOLDER ]]; then
      :
    elif [[ ! -d $FOLDER ]]; then
      :
    else
      # There is a result, it exists on disk... does it contain flacs?
      if ! compgen -G "$FOLDER/*.flac" >/dev/null; then
        :
      else
        VALIDDIRS="$VALIDDIRS"$'\n'"$FOLDER"
      fi
    fi
  ((FOLDERCOUNT++))
  done <<< "$DIRBASE"

  rm -f "$CONFDIR/tmp/musicfilter.txt" 2>/dev/null
  echo "$VALIDDIRS" > "$CONFDIR/txt/searchfilter.txt"

  $SEDPROG -i '/^[[:space:]]*$/d' "$CONFDIR/txt/searchfilter.txt" 2>/dev/null      # Remove blank line from top of file list, should there be one
  $SEDPROG -i '/concat(/d' "$CONFDIR/txt/searchfilter.txt" 2>/dev/null             # Remove query from top of file list, should it get into there

  sleep .4
fi
}

function play_filter {
MAXLOOPS=0; PLAYS=1
MAXLOOPS=$(cat "$CONFDIR/txt/searchfilter.txt" | wc -l)

if [[ $MAXLOOPS -eq 0 ]]; then
  clear	
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

# Executable code starts here
# ================================================================================
unset SQLSTMT
prompt_filter
if [[ $CANCELLED -eq  0 ]]; then play_filter; fi

# Reset terminal titlebar
if [[ $(uname -a) == *"Darwin"* ]]; then 
  echo -ne "\033]0; Giocoso \007"
else
  echo -en "\033]0; Giocoso \007\c"
fi