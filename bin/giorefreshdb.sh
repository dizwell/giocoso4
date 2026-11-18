#!/usr/bin/env bash
####################################################################
#
# giorefreshdb: refreshes a giocoso4 database. Refreshes can be 
# full or fast, with the refresh type being specified at time of 
# calling with parameter 'full' or 'fast'. If called by a cron
# job, a music folder must also be specified, otherwise an interactive
# folder-selection form will be displayed.
#
# Files used:
# filesystem_flacs.txt: folder names from find or fd
# db_flacs.txt: folder names from the giocoso4 database
# new_flacs.txt: difference between filesystem and db_flacs
# dead_flacs.txt: difference between db_flacs and filesystem
# analysed_flacs.txt: metadata-scanned new_flacs
# 
#
####################################################################
MUSICDIR=$FILEPREFIX GOODMUSIC=0
DIRCOUNT=0 PERCENTAGE=0

# Initiate an empty array that will ultimate contain a list of folders to scan
newflacfolders=()
# Create a dbops folder if it doesn't already exist (ignore creation errors if it does)
mkdir -p $CONFDIR/txt/dbops >/dev/null 2>&1

trap ctrl_c INT  # Trap interrupted database refreshes, so we can clean up properly

function ctrl_c() {
clear
clear_tracks
rm -f "$CONFDIR/txt/dbops/"*.txt >/dev/null 2>&1
exit 0
}

function get_fs_flacs {
if [[ $(uname -s) == Darwin ]]; then 
  if [[ $PROMPTS == "on" ]]; then
    # Start by getting a list of all folders containing FLAC files, regardless of fast or full refresh (Find and fd are deliberately hard-coded here)
    tput cup 25 1; MESSAGE="Scanning file system for FLACs. Please wait..."  
    if command -v fd >/dev/null 2>&1; then
      fd . "$SEARCHDIR" -e flac -x echo "{//}" | iconv -f UTF-8-MAC -t UTF-8 | sort --parallel=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null) -u 2>/dev/null >> "$CONFDIR/txt/dbops/filesystem_flacs.txt" & spinner $!
    else
      find "$SEARCHDIR" -name "*.flac" -exec dirname {} + | iconv -f UTF-8-MAC -t UTF-8 | sort --parallel=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null) -u 2>/dev/null >> "$CONFDIR/txt/dbops/filesystem_flacs.txt" & spinner $!
    fi
  else # Same as above, but without the spinner
    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting non-interactive file system scan of $SEARCHDIR..." >> "$CONFDIR/txt/dbops/dbrefresh.log"
    if command -v fd >/dev/null 2>&1; then
      fd . "$SEARCHDIR" -e flac -x echo "{//}" | iconv -f UTF-8-MAC -t UTF-8 | sort --parallel=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null) -u 2>/dev/null >> "$CONFDIR/txt/dbops/filesystem_flacs.txt"
    else
      find "$SEARCHDIR" -name "*.flac" -exec dirname {} + | iconv -f UTF-8-MAC -t UTF-8 | sort --parallel=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null) -u 2>/dev/null >> "$CONFDIR/txt/dbops/filesystem_flacs.txt"
    fi
	FLACCOUNT=$(($(wc -l < "$CONFDIR/txt/dbops/filesystem_flacs.txt")))
	echo "$(date '+%Y-%m-%d %H:%M:%S') $FLACCOUNT files found on the file system" >> "$CONFDIR/txt/dbops/dbrefresh.log"
  fi
  
else
  # Same code block, but without the normalisation code required to deal with Unicode characters on macOS	
  if [[ $PROMPTS == "on" ]]; then
    if command -v fd >/dev/null 2>&1; then
      fd . "$SEARCHDIR" -e flac -x echo "{//}" | sort --parallel=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null) -u 2>/dev/null >> "$CONFDIR/txt/dbops/filesystem_flacs.txt" & spinner $!
    else
      find "$SEARCHDIR" -name "*.flac" -exec dirname {} + | sort --parallel=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null) -u 2>/dev/null >> "$CONFDIR/txt/dbops/filesystem_flacs.txt" & spinner $!
    fi
  else # Same as above, but without the spinner
    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting non-interactive file system scan of $SEARCHDIR..." >> "$CONFDIR/txt/dbops/dbrefresh.log"
    if command -v fd >/dev/null 2>&1; then
      fd . "$SEARCHDIR" -e flac -x echo "{//}" | sort --parallel=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null) -u 2>/dev/null >> "$CONFDIR/txt/dbops/filesystem_flacs.txt"
    else
      find "$SEARCHDIR" -name "*.flac" -exec dirname {} + | sort --parallel=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null) -u 2>/dev/null >> "$CONFDIR/txt/dbops/filesystem_flacs.txt"
    fi
	FLACCOUNT=$(($(wc -l < "$CONFDIR/txt/dbops/filesystem_flacs.txt")))
	echo "$(date '+%Y-%m-%d %H:%M:%S') $FLACCOUNT files found on the file system" >> "$CONFDIR/txt/dbops/dbrefresh.log"
  fi	
fi	  
}

function get_db_flacs {
# If Fast Refresh, get a list of folders which are already in the database
# Note: this does not need Unicode normalisation, but it does require the client character set
# correctly matches the database's, which should be true for standard invocations of Giocoso 4
if [[ $PROMPTS == "on" ]]; then 
  tput cup 25 1; MESSAGE="Scanning database for FLACs. Please wait..."
  "${PROCONN[@]}" -N -B -e "select concat('$FILEPREFIX', filesuffix) from global_recordings order by 1" > "$CONFDIR/txt/dbops/db_flacs.txt" & spinner $!
else
  "${PROCONN[@]}" -N -B -e "select concat('$FILEPREFIX', filesuffix) from global_recordings order by 1" > "$CONFDIR/txt/dbops/db_flacs.txt"
  DBCOUNT=$(($(wc -l < "$CONFDIR/txt/dbops/db_flacs.txt")))
  echo "$(date '+%Y-%m-%d %H:%M:%S') $DBCOUNT files found in the database" >> "$CONFDIR/txt/dbops/dbrefresh.log"
fi
}

function compute_diffs {
# Fast refreshes take 'all FLACs' and subtract 'already known about FLACs' to generate a list a list of new folders to scan
if [[ $PROMPTS == "on" ]]; then 
  tput cup 25 1; MESSAGE="Checking for removed FLACs. Please wait..."
  awk 'FILENAME==ARGV[1] { seen[$0]=1; next } !($0 in seen)' "$CONFDIR/txt/dbops/db_flacs.txt" "$CONFDIR/txt/dbops/filesystem_flacs.txt" > "$CONFDIR/txt/dbops/new_flacs.txt" & spinner $!
else
  awk 'FILENAME==ARGV[1] { seen[$0]=1; next } !($0 in seen)' "$CONFDIR/txt/dbops/db_flacs.txt" "$CONFDIR/txt/dbops/filesystem_flacs.txt" > "$CONFDIR/txt/dbops/new_flacs.txt"
  NEWCOUNT=$(($(wc -l < "$CONFDIR/txt/dbops/new_flacs.txt")))
  echo "$NEWCOUNT FLACs are new and will be added to the database" >> "$CONFDIR/txt/dbops/dbrefresh.log"
fi

# Now do it in reverse: create a list of 'recordings the database has which are no longer on disk'
if [[ $PROMPTS == "on" ]]; then 
  tput cup 25 1; MESSAGE="Computing which FLACs are new. Please wait..."
  awk 'FILENAME==ARGV[1] { seen[$0]=1; next } !($0 in seen)' "$CONFDIR/txt/dbops/filesystem_flacs.txt" "$CONFDIR/txt/dbops/db_flacs.txt" > "$CONFDIR/txt/dbops/dead_flacs.txt" & spinner $!
else
  awk 'FILENAME==ARGV[1] { seen[$0]=1; next } !($0 in seen)' "$CONFDIR/txt/dbops/filesystem_flacs.txt" "$CONFDIR/txt/dbops/db_flacs.txt" > "$CONFDIR/txt/dbops/dead_flacs.txt"
  DEADCOUNT=$(($(wc -l < "$CONFDIR/txt/dbops/dead_flacs.txt")))
  echo "$DEADCOUNT FLACs no longer exist and need to be removed from the database" >> "$CONFDIR/txt/dbops/dbrefresh.log"
fi
}

function show_scan_progress {
# On-screen feedback while scanning: the folder being analysed (on line 25) and a percentage gauge.
tput civis; tput cup 25 1; echo -en "                                                                                             "  # Blank out 93 characters on line 25
tput cup 25 4; tput setaf $INFOTEXT; tput civis; DISPLAYDIR=${f/$MUSICDIR/…};                                                        # Remove MUSICDIR from path
if [[ ${#DISPLAYDIR} -gt 90 ]]; then
  DISPLAYDIR=$(printf '%s' "$DISPLAYDIR" | cut -c1-85)  # Trim to 85 characters long if longer
  DISPLAYDIR="$DISPLAYDIR>"
fi
printf '%s' "$DISPLAYDIR"
DIRCOUNT=$((DIRCOUNT+1)); NEWPERCENTAGE=$(bc <<<"scale=2; $DIRCOUNT/$TOTALDIRS*100"); NEWPERCENTAGE=${NEWPERCENTAGE%.*}
if [[ $DIRCOUNT -eq 1 ]]; then
  echo $PERCENTAGE | dialog --backtitle "Giocoso Database Refresh" --gauge "Analyzing music files in $TOTALDIRS folders..." 10 70 0  # We fake an early dialog entry to indicate progress, otherwise they will stare at a blank screen for a long time when handling a large music collection
elif [[ $((NEWPERCENTAGE - $PERCENTAGE)) -ge 2 ]]; then
  PERCENTAGE=$NEWPERCENTAGE
  echo $PERCENTAGE | dialog --backtitle "Giocoso Database Refresh" --gauge "Analyzing music files in $TOTALDIRS folders..." 10 70 0
fi
}

function analyse_folder {
# Analyse every FLAC in one folder: give it a seek table if it lacks one, read its tags, and add a line for it to
# analysed_flacs.txt. One copy only, used by every refresh, whether shown on screen or run unattended.
for g in "$f"/*.flac; do
  # Some players and streamers need a seek table: give any FLAC without one a 100-point table. Existing tables are left
  # alone, except an empty one (0 points, which some converters write): that counts as none, and is removed and replaced.
  SEEKPOINTS=$($METAFLAC --list --block-type=SEEKTABLE "$g" 2>/dev/null | awk '/seek points:/ {print $3; exit}')
  if [[ -z $SEEKPOINTS || $SEEKPOINTS -eq 0 ]]; then
    [[ -n $SEEKPOINTS ]] && $METAFLAC --remove --block-type=SEEKTABLE "$g" >/dev/null 2>&1
    $METAFLAC --add-seekpoint=100x "$g" >/dev/null 2>&1
  fi
  ARTIST=$($METAFLAC $UTFCHARS --show-tag=Artist "$g" | $SEDPROG 's/.*=//g' 2>/dev/null)
  ALBUM=$($METAFLAC $UTFCHARS --show-tag=Album "$g" | $SEDPROG 's/.*=//g' 2>/dev/null)
  GENRE=$($METAFLAC $UTFCHARS --show-tag=Genre "$g" | $SEDPROG 's/.*=//g' 2>/dev/null)
  COMMENT=$($METAFLAC $UTFCHARS --show-tag=Comment "$g" | $SEDPROG 's/.*=//g' 2>/dev/null)
  PERFORMER=$($METAFLAC $UTFCHARS --show-tag=Performer "$g" | $SEDPROG 's/.*=//g' 2>/dev/null)
  if [[ -z $PERFORMER ]]; then
    PERFORMER=$(echo "$COMMENT" | cut -d "," -f 1); PERFORMER=$(echo "$PERFORMER" | cut -d "(" -f 1); PERFORMER=$(echo "$PERFORMER" | cut -d ":" -f 1)
  fi
  TRACKNUMBER=$($METAFLAC $UTFCHARS --show-tag=Tracknumber "$g" | $SEDPROG 's/.*=//g' 2>/dev/null)
  TITLE=$($METAFLAC $UTFCHARS --show-tag=Title "$g" | $SEDPROG 's/.*=//g' 2>/dev/null)
  DURATION=$($FFPROBE -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$g" 2>/dev/null)
  DURATION=$(echo "$DURATION" | bc)

  # Make the variables double-quote free -even the ones unlikely to have double quotes, just in case. Replace " with ##@##
  # which is a 'weird' combo of characers unlikely to exist in nature. That way we can spot them again later on!
  ARTIST="${ARTIST//\"/##@##}"
  ALBUM="${ALBUM//\"/##@##}"
  GENRE="${GENRE//\"/##@##}"
  COMMENT="${COMMENT//\"/##@##}"
  PERFORMER="${PERFORMER//\"/##@##}"
  TITLE="${TITLE//\"/##@##}"
  FOLDER="${f//\"/##@##}"
  # Tags go into a pipe-delimited file, one line per FLAC: a | in a tag would shift every later field, and a line
  # break (a multi-line comment, or a tag with several values) would split the line. So strip pipes, and turn
  # line breaks into spaces (which also puts several values of one tag on one line, separated by spaces).
  for v in ARTIST ALBUM GENRE COMMENT PERFORMER TRACKNUMBER TITLE; do
    printf -v "$v" '%s' "${!v//|/}"; printf -v "$v" '%s' "${!v//$'\n'/ }"; printf -v "$v" '%s' "${!v//$'\r'/ }"
  done

  # Now concatenate cleaned variables into one giant string and echo to a CSV delimited by pipes
  echo "$FOLDER|$ARTIST|$ALBUM|$GENRE|$COMMENT|$PERFORMER|$TRACKNUMBER|$TITLE|$DURATION" >> "$CONFDIR/txt/dbops/analysed_flacs.txt"
done
}

function scan_flacs {
TOTALDIRS=$(cat "$CONFDIR/txt/dbops/new_flacs.txt" | wc -l)   # Number of folders to analyze
readarray -t newflacfolders < "$CONFDIR/txt/dbops/new_flacs.txt"

if [[ $PROMPTS == "on" ]]; then
  tput cup 25 1; echo -e "                                                                                          "
fi
for f in "${newflacfolders[@]}"; do
  if [[ $PROMPTS == "on" ]]; then
    show_scan_progress                                         # On screen: show the folder and the gauge
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') Analysing $f" >> "$CONFDIR/txt/dbops/dbrefresh.log"   # Unattended (cron, say): just log it
  fi
  if [[ -n $f ]]; then
    analyse_folder
  fi
done
}

function thousands {
# A whole number with thousands separators: 17597 becomes 17,597 (as Niente)
local NUM="$1" OUT=""
while (( ${#NUM} > 3 )); do OUT=",${NUM: -3}$OUT"; NUM="${NUM:0:${#NUM}-3}"; done
printf '%s' "$NUM$OUT"
}

function check_data_loss {
# One rule for both refresh types (as Niente): if more than a fifth of the database's recordings weren't found on
# disk (an unmounted or partly available share, say), the refresh is suspect. From the menu, warn and ask (default No);
# unattended, refuse. Either way, a refresh that doesn't go ahead changes nothing. An empty database can never trip it.
# Returns 0 to go ahead, 1 to stop.
DBCOUNT=$(($(wc -l < "$CONFDIR/txt/dbops/db_flacs.txt" 2>/dev/null || echo 0)))
DEADCOUNT=$(($(wc -l < "$CONFDIR/txt/dbops/dead_flacs.txt" 2>/dev/null || echo 0)))
if (( DBCOUNT == 0 || DEADCOUNT * 5 <= DBCOUNT )); then return 0; fi
if [[ $PROMPTS == "on" ]]; then
  if dialog --stdout --backtitle "Giocoso Database Refresh" --title " Data Loss Warning! " --no-mouse --defaultno --yesno "\n$(thousands $DEADCOUNT) of the $(thousands $DBCOUNT) recordings in the database could not be found in your music folder. Continuing would remove them from the database. Is your music folder fully available?\n\nAre you sure you want to continue?" 14 80; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') $DEADCOUNT of $DBCOUNT recordings were not found in the music folder: refresh continued at the user's request." >> "$CONFDIR/txt/dbops/dbrefresh.log"
    return 0
  fi
  dialog --stdout --backtitle "Giocoso Database Refresh" --title " Refresh Cancelled! " --msgbox "\nThe database refresh has been cancelled.\n\nNothing about your existing Giocoso database has been altered." 12 80
  echo "$(date '+%Y-%m-%d %H:%M:%S') Refresh cancelled at the data-loss warning: $DEADCOUNT of $DBCOUNT recordings were not found in the music folder, so nothing has been changed." >> "$CONFDIR/txt/dbops/dbrefresh.log"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') Unattended refresh refused: $DEADCOUNT of $DBCOUNT recordings in the database were not found in the music folder (more than a fifth), so nothing has been changed. If they really have gone, run a refresh from the menu." >> "$CONFDIR/txt/dbops/dbrefresh.log"
fi
rm -f "$CONFDIR/txt/dbops/"{filesystem,db,new,dead,analysed}_flacs.txt >/dev/null 2>&1
tput cvvis
return 1
}

function refresh_database {
if [[ $REFRESH_TYPE == "full" ]]; then
  # A full refresh empties global_recordings and rebuilds it from the scan (check_data_loss has already run)
  "${PROCONN[@]}" -N -B -e "delete from global_recordings" 2>/dev/null
fi

"${PROCONN[@]}" -N -B -e "delete from tracks" 2>/dev/null

# Regardless of refresh type, now load the analysed flacs file into an empty tracks table
"${PROCONN[@]}" -e "LOAD DATA LOCAL INFILE '$CONFDIR/txt/dbops/analysed_flacs.txt' INTO TABLE tracks CHARACTER SET utf8mb4 FIELDS TERMINATED BY '|' ESCAPED BY ''" 2>/dev/null

# Now to replace the weirdness in the various columns of TRACKS, if any. This puts back double quotes.
"${PROCONN[@]}" -N -B -e "update tracks set composer=replace(composer,'##@##','\"');" >/dev/null 2>&1
"${PROCONN[@]}" -N -B -e "update tracks set composition=replace(composition,'##@##','\"');" >/dev/null 2>&1
"${PROCONN[@]}" -N -B -e "update tracks set genre=replace(genre,'##@##','\"');" >/dev/null 2>&1
"${PROCONN[@]}" -N -B -e "update tracks set comment=replace(comment,'##@##','\"');" >/dev/null 2>&1
"${PROCONN[@]}" -N -B -e "update tracks set performer=replace(performer,'##@##','\"');" >/dev/null 2>&1
"${PROCONN[@]}" -N -B -e "update tracks set title=replace(title,'##@##','\"');" >/dev/null 2>&1
"${PROCONN[@]}" -N -B -e "update tracks set dirname=replace(dirname,'##@##','\"');" >/dev/null 2>&1

# Now construct the other required tables as selects from the tracks table
# First, select essentially the first track in each album to stand representative for the entire recording
"${PROCONN[@]}" -N -B -e "insert ignore into global_recordings select distinct MD5(CONCAT(composer, composition)), dirname, composer, composition, genre, comment, performer, null from tracks;" >/dev/null 2>&1

# Now update the filesuffix so that it does NOT contain the fileprefix
"${PROCONN[@]}" -N -B -e "UPDATE global_recordings SET filesuffix = REPLACE(filesuffix, '$FILEPREFIX', '');" >/dev/null 2>&1

# Next, set the duration of the album to be that for all the tracks in the same folder
"${PROCONN[@]}" -N -B -e "update global_recordings g join (select composer, replace(dirname, '$FILEPREFIX', '') as filesuffix, sum(duration) as duration from tracks group by composer, dirname) a on a.composer = g.composer and a.filesuffix = g.filesuffix set g.duration = a.duration" >/dev/null 2>&1

# Clear out the intermediate working files
rm -f "$CONFDIR/txt/dbops/filesystem_flacs.txt" >/dev/null 2>&1
rm -f "$CONFDIR/txt/dbops/db_flacs.txt" >/dev/null 2>&1
rm -f "$CONFDIR/txt/dbops/new_flacs.txt" >/dev/null 2>&1
rm -f "$CONFDIR/txt/dbops/dead_flacs.txt" >/dev/null 2>&1
rm -f "$CONFDIR/txt/dbops/analysed_flacs.txt" >/dev/null 2>&1
tput cvvis
}

function delete_obsolete {
# If there is a file of FLACs to be deleted, then do that now, too (check_data_loss has already run)
if [[ -f $CONFDIR/txt/dbops/dead_flacs.txt ]]; then
  while IFS= read -r FULLPATH; do
    FILESUFFIX="${FULLPATH#$FILEPREFIX}"
	FILESUFFIX="${FILESUFFIX//\'/\'\'}"
	SQLSTMT="delete from global_recordings where filesuffix='$FILESUFFIX'"
    "${PROCONN[@]}" -N -B -e "$SQLSTMT" 2>/dev/null
    if [[ $PROMPTS == "on" ]]; then tput civis; tput cup 25 1; tput setaf $MAINTEXT; echo -en "Deleting old recordings from the global database..."; tput cvvis; fi
  done < "$CONFDIR/txt/dbops/dead_flacs.txt"	
fi	
}

function clear_tracks {
"${PROCONN[@]}" -N -B -e "delete from tracks;" 2>/dev/null
}

# ==============================================================
# Functional code starts here
# ==============================================================
# This code expects:
# $1 = music folder to scan
# $2 = refresh type (full or fast)
#
# When running interactively (i.e., via the main program menu), the
# refresh type [$2] is specified by the menu options
# so we don't need to prompt for it. The music folder to scan will however
# be hard-coded to be "NODIR". If we see "NODIR", we therefore prompt for the
# user to specify a folder using a dialog form.
#
# Non-interactive refreshes (i.e., via crontab or similar) need to 
# spell out both parameters, accurately.

# Make sure we start clean
rm -f "$CONFDIR/txt/dbops/filesystem_flacs.txt" >/dev/null 2>&1
rm -f "$CONFDIR/txt/dbops/db_flacs.txt" >/dev/null 2>&1
rm -f "$CONFDIR/txt/dbops/new_flacs.txt" >/dev/null 2>&1
rm -f "$CONFDIR/txt/dbops/dead_flacs.txt" >/dev/null 2>&1
rm -f "$CONFDIR/txt/dbops/analysed_flacs.txt" >/dev/null 2>&1

MUSIC_FOLDER="$1"  
REFRESH_TYPE="$2"
REFRESHSTOPPED=0

if [[ $MUSIC_FOLDER == "NODIR" ]]; then
  PROMPTS=on
  tput civis	
  while [[ $GOODMUSIC -eq 0 ]]; do
    SEARCHDIR=$(dialog --backtitle "Giocoso Database Refresh" --title " Select the root folder of your music collection " --dselect "$MUSICDIR" 12 80 0 3>&1 1>&2 2>&3 3>&- )
    if [[ $? -ne 0 ]]; then break; fi
    if ! [[ -d $SEARCHDIR ]]; then
      unset SEARCHDIR
      dialog --stdout --backtitle "Giocoso Database Refresh" --msgbox "That folder doesn't appear to exist! Try again." 8 80
    else
      GOODMUSIC=1
    fi
  done
else
  SEARCHDIR="$MUSIC_FOLDER"
  if ! [[ -d $SEARCHDIR ]]; then
    unset SEARCHDIR
    dialog --stdout --backtitle "Giocoso Database Refresh" --msgbox "That folder doesn't appear to exist! Try again." 8 80
  else
    GOODMUSIC=1
    PROMPTS=off
  fi
fi

# But now we know what we're searching for, the same code applies to all invocations of the refresh process
if [[ $GOODMUSIC -eq 1 ]]; then
  if [[ $REFRESH_TYPE == "fast" ]]; then
  	printf '=%.0s' {1..80} >> "$CONFDIR/txt/dbops/dbrefresh.log"  # Append to existing log
	printf '\n' >> "$CONFDIR/txt/dbops/dbrefresh.log"
  	echo "$(date '+%Y-%m-%d %H:%M:%S') Starting a $REFRESH_TYPE database refresh" >> "$CONFDIR/txt/dbops/dbrefresh.log"
    get_fs_flacs
	get_db_flacs
    compute_diffs
    if check_data_loss; then                                          # Before any tags are read: a suspect refresh changes nothing
	  scan_flacs
      delete_obsolete                                                 # Before refresh_database, which removes the working files it reads
      refresh_database
    else
      REFRESHSTOPPED=1
    fi
  elif [[ $REFRESH_TYPE == "full" ]]; then
  	printf '=%.0s' {1..80} > "$CONFDIR/txt/dbops/dbrefresh.log"  # Start a new log
  	printf '\n' >> "$CONFDIR/txt/dbops/dbrefresh.log"
  	echo "$(date '+%Y-%m-%d %H:%M:%S') Starting a $REFRESH_TYPE database refresh" >> "$CONFDIR/txt/dbops/dbrefresh.log"
    get_fs_flacs
	get_db_flacs
    compute_diffs
    if check_data_loss; then                                          # Before any tags are read: a suspect refresh changes nothing
	  cat "$CONFDIR/txt/dbops/filesystem_flacs.txt" > "$CONFDIR/txt/dbops/new_flacs.txt" & spinner $!
	  scan_flacs
	  refresh_database
    else
      REFRESHSTOPPED=1
    fi
  fi
  
  clear_tracks

  if [[ $REFRESHSTOPPED -eq 1 ]]; then
    :                                                                 # check_data_loss has already said why (on screen and in the log)
  elif [[ $PROMPTS == "on" ]]; then 
    dialog --stdout --backtitle "Giocoso Database Refresh" --msgbox "Database refresh complete. Press OK to return to the main menu." 8 80
	tput cvvis
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') File system scan completed." >> "$CONFDIR/txt/dbops/dbrefresh.log"
	echo "Script completed in $((SECONDS / 60)) minutes $((SECONDS % 60)) seconds" >> "$CONFDIR/txt/dbops/dbrefresh.log"
	printf '=%.0s' {1..80} >> "$CONFDIR/txt/dbops/dbrefresh.log"
	printf '\n\n\n' >> "$CONFDIR/txt/dbops/dbrefresh.log"
  fi
fi

# Re-instate global trap as we exit
trap exit_program INT