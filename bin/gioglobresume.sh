#!/usr/bin/env bash
####################################################################
#
# A function to resume a play paused on a different device, using
# the global database to know what and where to resume
#
####################################################################
unset GPLAYDIR
erase_logo
function pick_recording {
old_IFS=$IFS
DEVLIST=""
countresults=$("${PROCONN[@]}" -N -B -e "select count(*) from global_pauses")
if [[ $countresults -gt 1 ]]; then
  IFS=$'\n' read -r -d '' -a results < <("${PROCONN[@]}" -N -B -e "select rechashvalue, composition from global_recordings where rechashvalue in (select rechashvalue from global_pauses) order by composition" && printf '\0')
  deviceitems=()
  for recname in "${results[@]}"; do
	  rechashvalue=$(echo "$recname" | cut -f1)
	  composition=$(echo "$recname" | cut -f2-)
      deviceitems+=("$rechashvalue" "${composition:0:70}" off)
  done
  CHOSENRECORD=$(dialog --no-tags --backtitle "Giocoso Global Resume" --radiolist " Pick the paused recording to resume " 12 95 0 "${deviceitems[@]}" 3>&1 1>&2 2>&3 3>&-)
  exitStatus=$?
  if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then
      NOPAUSED=1
  elif [[ ! -z $CHOSENRECORD ]]; then
      NOPAUSED=0
  else
      NOPAUSED=1
  fi
elif [[ $countresults -eq 1 ]]; then
  CHOSENRECORD=$("${PROCONN[@]}" -N -B -e "select distinct rechashvalue from global_recordings where rechashvalue in (select rechashvalue from global_pauses)" )
  NOPAUSED=0
else
  dialog --stdout --backtitle "Giocoso Global Resume" --title " Nothing to resume! " --msgbox "\nThere are currently no recordings known to be in a state of paused playback, so there's nothing to resume." 10 80
  NOPAUSED=1
fi
IFS=${old_IFS}
}

function play_resume {
LINESELECTIONS=1; SELECTIONS=1; TOTALDUR=0; duration=0
echo "Global Resume" > "$CONFDIR/txt/searchfilter.txt"
RESUMPTION=$("${PROCONN[@]}" -N -B -e "select concat(filesuffix,'|',current_play_location) from global_recordings r, global_pauses p where r.rechashvalue = p.rechashvalue and r.rechashvalue='$CHOSENRECORD'")
if [[ ! -z $RESUMPTION ]]; then
  # RESUMPTION will be a pipe-delimited pair: eg, "/B/Benjamin Britten/Peter Grimes|932": the folder name first; and then 
  # the current pause point, in seconds. Assign each component to separate variables now:	
  GPLAYDIR=$(echo "$RESUMPTION" | awk -F "|" '{print $1}'); GPLAYDIR="$FILEPREFIX$GPLAYDIR"
  GRESUMEFROM=$(echo "$RESUMPTION" | awk -F "|" '{print $2}'); GRESUMEFROM=${GRESUMEFROM%%.*}; GRESUMEFROM=$((GRESUMEFROM - 5))
  if [[ $GRESUMEFROM -lt 0 ]]; then GRESUMEFROM=0; fi
  PLAY_OFFSET=$GRESUMEFROM                    # Where in the recording this play starts: needed by handle_pause to store a true position
  glob_compute_duration
  compute_replaygain
  glob_play_music
  clearscreen
else
  dialog --stdout --backtitle "Giocoso Global Resume" --title " Nothing found to resume! " --msgbox "\nThe global database is referencing a recording which appears not to exist, so playback can't be resumed." 10 80
fi
}

function glob_compute_duration {
PLAYLENGTH=0 PLAYSECS=0
SQLSTMT="select ifnull(sum(duration),0) from global_recordings where rechashvalue='$CHOSENRECORD'"
TOTALDUR=$("${PROCONN[@]}" -N -B -e "$SQLSTMT")
TOTALDUR=$(round "$TOTALDUR/1" 0)                               # Converts the returned value to an integer number of seconds
ALREADYPLAYED=$(round "$GRESUMEFROM/1" 0)                       # Converts the resumption point to an integer number of seconds
PLAYSECS=$(($TOTALDUR - $ALREADYPLAYED))                        # Converts the total duration of the recording into just the amount left to complete it
PLAYLENGTH=$($DATEPROG -d@$TOTALDUR -u +%H:%M:%S)               # Duration of current recording, in hh:mm:ss format
}

function compute_replaygain {
# This code reads the REPLAYGAIN_ALBUM_GAIN and REPLAYGAIN_ALBUM_PEAK tags
# from the first FLAC in a folder.
#
# The REPLAYGAIN_ALBUM_GAIN tag specifies the gain adjustment for the album.
# If that adjustment exceeds +7.5dB, we cap it at +7.5dB, storing the result
# in CAPPED_GAIN.
#
# However, applying the album gain can cause clipping if the album's **peak**
# is already close to 0dBFS. We therefore calculate the maximum gain permitted
# by REPLAYGAIN_ALBUM_PEAK and use the lower of that limit and CAPPED_GAIN.
# This ensures that the adjusted peak does not exceed 0dBFS. 
#
# If the peak tag is missing or invalid, we apply 0dB as a safe fallback.
#
# In short, this code:
# * Caps the gain at +7.5 dB.
# * Reduces it further if the peak requires it to avoid exceeding 0 dBFS.
# * Applies 0 dB and displays ~ if the peak tag is missing or invalid.
# * Displays the applied gain to two decimal places.

f=$(find "$GPLAYDIR" -maxdepth 1 -name "*.flac" | sort | head -n 1)
RPG_ALBUMGAIN=$($METAFLAC $UTFCHARS --show-tag=REPLAYGAIN_ALBUM_GAIN "$f" | $SEDPROG s/.*=//g)
RPG_ALBUMPEAK=$($METAFLAC $UTFCHARS --show-tag=REPLAYGAIN_ALBUM_PEAK "$f" | $SEDPROG s/.*=//g)

if [[ -n $RPG_ALBUMGAIN && ${USERPG^^} == "YES" ]]; then
  NUMERIC_GAIN="${RPG_ALBUMGAIN%dB}"

  # Cap the requested gain at +7.5dB.
  CAPPED_GAIN=$(awk -v gain="$NUMERIC_GAIN" 'BEGIN { if (gain > 7.5) print 7.5; else print gain }')

  # Check whether the peak tag is present, numeric, and greater than zero.
  if [[ $RPG_ALBUMPEAK =~ ^[0-9]*\.?[0-9]+$ ]] &&
     awk -v peak="$RPG_ALBUMPEAK" 'BEGIN { exit !(peak > 0) }'; then

    # Calculate the maximum gain permitted by the album peak.
    PEAK_LIMIT=$(awk -v peak="$RPG_ALBUMPEAK" 'BEGIN { print -20*log(peak)/log(10) }')

    # Use whichever is lower: the capped gain or the peak limit.
    SAFE_GAIN=$(awk -v gain="$CAPPED_GAIN" -v limit="$PEAK_LIMIT" 'BEGIN { if (gain > limit) print limit; else print gain }' | $SEDPROG 's/[[:space:]]*$//')
    
	# Display a tilde if the gain was reduced.
    CORRECTION_FLAG=$(awk -v original="$NUMERIC_GAIN" -v safe="$SAFE_GAIN" 'BEGIN { if (safe < original) print "~"; else print "" }')
  else
    # Missing or invalid peak: do not apply ReplayGain.
    SAFE_GAIN="0"
    CORRECTION_FLAG="~"
  fi

  RPG_ALBUMGAIN="${SAFE_GAIN}dB"
  AF_FILTER="adelay=2000:all=1,volume=$RPG_ALBUMGAIN"

  DISPLAYRPG=$(LC_NUMERIC=C printf "%.2f\n" "$SAFE_GAIN")

  # Volume reductions already have a minus sign; increases need a plus sign.
  if [[ ${DISPLAYRPG:0:1} == "-" ]]; then RPGSIGN=""; else RPGSIGN="+"; fi
  DISPLAYRPG="$RPGSIGN$DISPLAYRPG dB$CORRECTION_FLAG"
  RPGAIN="$DISPLAYRPG"
else
  AF_FILTER="adelay=2000:all=1"
  DISPLAYRPG="None"
  RPGAIN="$DISPLAYRPG"
fi
}

function glob_play_music {
VALIDDIR=$(ls "$GPLAYDIR" 2>/dev/null | wc -l)
if [[ $VALIDDIR -gt 0 ]]; then
  cd "$GPLAYDIR"
fi

# Find the first FLAC in the folder and extract data from it we'll use to describe the entire composition
f=$(find "$GPLAYDIR" -maxdepth 1 -name "*.flac" | sort | head -n 1)
  
if [[ $($METAFLAC --show-md5sum "$f" 2>&1 | $GREPPROG -i error | wc -l) -eq 0 ]]; then   # Big jump to end of function: if it's not a valid FLAC file, don't bother trying to play it

  if [[ $($METAFLAC $UTFCHARS --export-picture-to=$CONFDIR/art/albumart.jpg "$f" 2>&1 | $GREPPROG "ERROR" | wc -l) -gt 0 ]]; then
    cp "$CONFDIR/art/genericalbumart.jpg" "$CONFDIR/art/albumart.jpg"
  else
    $METAFLAC $UTFCHARS --export-picture-to="$CONFDIR/art/albumart.jpg" "$f" >/dev/null 2>&1
  fi

  displaydate=$($METAFLAC $UTFCHARS --show-tag=Year "$f" | $SEDPROG 's/.*=//g' 2>/dev/null); if [[ -z $displaydate ]]; then displaydate=$($METAFLAC $UTFCHARS --show-tag=Date "$f" | $SEDPROG 's/.*=//g' 2>/dev/null); fi
  displaygenre=$($METAFLAC $UTFCHARS --show-tag=Genre "$f" | $SEDPROG 's/.*=//g' 2>/dev/null)
  displaycomment=$($METAFLAC $UTFCHARS --show-tag=Comment "$f" | $SEDPROG 's/.*=//g' 2>/dev/null); THISCOMMENT="$displaycomment"
  if [[ ${#displaycomment} -gt 330 ]]; then
    displaycomment="${displaycomment::330}…"
  fi
  displaycomp=$($METAFLAC $UTFCHARS --show-tag=Artist "$f" | $SEDPROG 's/.*=//g' 2>/dev/null); THISARTIST="$displaycomp"
  displaywork=$($METAFLAC $UTFCHARS --show-tag=Album "$f" | $SEDPROG 's/.*=//g' 2>/dev/null); THISALBUM="$displaywork"
  THISDISTINGUISHED_ARTIST=$($METAFLAC $UTFCHARS --show-tag=Performer "$f" | $SEDPROG 's/.*=//g' 2>/dev/null)
  displaywork=${displaywork%%(*}
  FULLWORKNAME=$displaywork
  probeattributes=$($FFPROBE -hide_banner "$f" |& $GREPPROG Stream | $GREPPROG Audio)
  displayhertz=$(echo "$probeattributes" | awk '{print $5 $6}')
  displaychannels=$(echo "$probeattributes" | awk '{print $7}')
  displayhertz="${displayhertz::-1}"; displaychannels="${displaychannels::-1}"
  displaydepth=$(echo "$probeattributes" | awk '{print $8}'); if [[ $displaydepth == "s16" ]]; then displaydepth="16-bit"; else displaydepth="24-bit"; fi

  if [[ ! -z $displaycomp ]]; then   	 # For apostrophes, if a word ends in single-s, add only an apostrophe. If it ends in ss or not in s at all, then it's apostrophe+s.
    if [[ ${displaycomp: -2} == ss ]]; then
      displayapostrophe="'s"
    elif [[ ${displaycomp: -1} == s ]]; then
      displayapostrophe="'"
    else
      displayapostrophe="'s"
    fi
  else
    displayapostrophe=""       			 # If, for some reason, they are playing un-tagged FLACs directly, then we can't be displaying this at all
  fi

  rm -f "$CONFDIR/txt/giocoso-tracklist.txt"
  for f in *.flac; do                    # Main loop around all FLACs to generate a 'virtual' playlist for gapless playback
    filename=$(gbasename "$f")
    albumdir=$(gdirname "$(pwd)"/"$f")
    echo "file #$(pwd)/$filename#" >> "$CONFDIR/txt/giocoso-tracklist.txt"
  done

  # Determine whether the selected recording has been played before and, if so, how many times.
  f=$(find "$GPLAYDIR" -name "*.flac" | sort | head -n 1)
  PLAYARTIST=$($METAFLAC $UTFCHARS --show-tag=Artist "$f" | $SEDPROG 's/.*=//g' 2>/dev/null)
  PLAYALBUM=$($METAFLAC $UTFCHARS --show-tag=Album "$f" | $SEDPROG 's/.*=//g' 2>/dev/null)
  RECHASHVALUE=$(echo -n "$PLAYARTIST$PLAYALBUM" | $MD5PROG | gawk '{print $1}')
  PLAYARTIST=$(echo "$PLAYARTIST" | $SEDPROG "s/'/\'\'/g" 2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)             				# Strips out semicolons and turns single quotes into double single quotes (otherwise SQL breaks on the insert)
  PLAYALBUM=$(echo "$PLAYALBUM" | $SEDPROG "s/'/\'\'/g" 2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)               				# Strips out semicolons and turns single quotes into double single quotes (otherwise SQL breaks on the insert)
  SQLSTMT="select count(*) from global_plays where rechashvalue='$RECHASHVALUE'"
  PREVIOUSPLAYS=$("${PROCONN[@]}" -N -B -e "$SQLSTMT")
  SQLSTMT="SELECT DATEDIFF(CURDATE(), DATE(MAX(STR_TO_DATE(playdate, '%Y-%m-%d %H:%i:%s')))) AS days_ago FROM global_plays WHERE rechashvalue='$RECHASHVALUE';"
  LASTPLAYED=$("${PROCONN[@]}" -N -B -e "$SQLSTMT" 2>/dev/null)
  SQLSTMT="SELECT DATEDIFF(CURDATE(), DATE(MAX(STR_TO_DATE(playdate, '%Y-%m-%d %H:%i:%s')))) AS days_ago FROM global_plays WHERE composer='$PLAYARTIST';"
  LASTCOMPOSERPLAYED=$("${PROCONN[@]}" -N -B -e "$SQLSTMT" 2>/dev/null)
  
  if [[ -z $LASTPLAYED || $LASTPLAYED == "NULL" ]]; then
    LASTPLAYED="Never"
  fi

  if [[ -z $LASTCOMPOSERPLAYED || $LASTCOMPOSERPLAYED == "NULL" ]]; then
    LASTCOMPOSERPLAYED="Never"
  fi

  $SEDPROG -i "s/'/'\\\''/g" "$CONFDIR/txt/giocoso-tracklist.txt" 2>/dev/null             					# Parse tracklist and replace single quotes with escaped version
  $SEDPROG -i "s/#/'/g" "$CONFDIR/txt/giocoso-tracklist.txt" 2>/dev/null
  source "$CONFDIR/bin/gioart.sh" "$displaycomp" "$displaywork"							# Create a displayable piece of album art+caption
  WORKNAMELength=${#FULLWORKNAME}; WORKNAMELines=$(( (WORKNAMELength + 45) / 45 ))				# Some maths to work out how many lines something takes, assuming a display width of 45 characters.
  tput cup  5 4; echo -en "                                              "
  tput cup 18 4; echo -en "                                              "
  tput cup 19 4; echo -en "                                              "
  tput cup 20 4; echo -en "                                              "
  tput cup 21 4; echo -en "                                              "
  tput cup 22 4; echo -en "                                              "
  tput cup 23 4; echo -en "                                              "

  tput cup 5 4; tput setaf "$MAINTEXT"; echo -en "$displaycomp$displayapostrophe"
  tput cup 17 0; tput setaf "$DRAWLINES"; echo -en "├─────────────────────────────────────────────────┤"
  tput cup 18 4; tput setaf "$MAINTEXT"; echo -en "Days since last play: "; tput setaf "$INFOTEXT"; echo -en "$LASTPLAYED : $LASTCOMPOSERPLAYED"
  tput cup 19 4; tput setaf "$MAINTEXT"; echo -en "Recording Year: "; tput setaf "$INFOTEXT"; echo -en "$displaydate"
  tput cup 20 4; tput setaf "$MAINTEXT"; echo -en "Genre: "; tput setaf "$INFOTEXT"; echo -en "$displaygenre"
  tput cup 21 4; tput setaf "$MAINTEXT"; echo -en "Audio Tech: "; tput setaf "$INFOTEXT"; echo -en "$displayhertz/$displaydepth"
  tput cup 22 4; tput setaf "$MAINTEXT"; echo -en "Previous plays: "; tput setaf "$INFOTEXT"; echo -en "$PREVIOUSPLAYS"
  tput cup 23 4; tput setaf "$MAINTEXT"; echo -en "ReplayGain Applied: "; tput setaf "$INFOTEXT"; echo -en "$DISPLAYRPG"

  readarray -t composition < <(echo "$FULLWORKNAME" | fmt -w 45)
  counter=0
  for i in "${!composition[@]}"; do
    ((counter++))
    tput cup $((5 + counter)) 4; tput setaf $INFOTEXT; echo -en "\033[1m\e[3m${composition[$i]}\e[0m\033[0m"
    lastline_reached=$counter
  done

  readarray -t performers < <(echo "$displaycomment" | fmt -w 45)
  counter=0
  for i in "${!performers[@]}"; do
    ((counter++))
    tput cup $((7 + $counter + $lastline_reached)) 4; echo -en "${performers[$i]}"
  done

  erase_logo
  tput cup 5 57; "$SIXEL" "$CONFDIR/art/albumart.jpg" 2>/dev/null

  TERMTITLE="$displaycomp - $displaywork - $THISDISTINGUISHED_ARTIST"; TERMTITLE=${TERMTITLE:0:99}      # Usually not needed, but put a limit on composer+composition name for display purposes,  in case the terminal doesn't truncate it itself
  echo -en "\033]0; Now playing: $TERMTITLE \007\c"                                                     # Setting terminal's titlebar
  
  # This bit does the actual playing of the virtual playlist, adding one second of silence on to the end, to ensure the playback completes properly.
  PLAYSTART_CLOCKTIME=$(date +%s)
  touch "$CONFDIR/txt/nowplaying.txt"
  sleep 1 # Just to give things time to catch up
  
  if [[ $(uname -a) == *"Darwin"* ]]; then
    if [[ $FORCE_PULSE -eq 1 ]]; then 
      "${PULSEENV[@]}" $FFMPEG -stats_period 1 -f concat -safe 0 -ss "$GRESUMEFROM" -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f pulse "default?async=1" |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
    else
      $FFMPEG -stats_period 1 -f concat -safe 0 -ss "$GRESUMEFROM" -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f audiotoolbox - |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
    fi
  elif [[ $(uname -a) == *microsoft* ]]; then
    AUDIODEVICE="PulseAudio"
    if [[ $FORCE_PULSE -eq 1 ]]; then
      "${PULSEENV[@]}" $FFMPEG -stats_period 1 -f concat -safe 0 -ss "$GRESUMEFROM" -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f pulse - |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
    else
      $FFMPEG -stats_period 1 -f concat -safe 0 -ss "$GRESUMEFROM" -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f pulse - |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
    fi
  else
    if [[ $FORCE_PULSE -eq 1 ]]; then
      AUDIODEVICE="PulseAudio"
      # Do this if running on Linux but use of Pulseaudio is forced in configuration file
      $FFMPEG -stats_period 1 -f concat -safe 0 -ss "$GRESUMEFROM" -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f pulse - |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
    else
      # Do this if running on Linux and Pulseaudio hasn't been forced on
      $FFMPEG -stats_period 1 -f concat -safe 0 -ss "$GRESUMEFROM" -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f alsa "$AUDIODEVICE" |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
    fi
  fi

  POSTPLAY_CLOCKTIME=$(date +%s)
  PLAY_ELAPSEDTIME=$(( POSTPLAY_CLOCKTIME - PLAYSTART_CLOCKTIME ))              # Want to determine how long ffmpeg played music for

  # Clean Up after Play Completes
  rm -f "$CONFDIR/txt/nowplaying.txt" 2>/dev/null
  echo "" > "$CONFDIR/txt/newplay.txt"
  $MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
  
  if [[ ! -f $CONFDIR/txt/terminate.txt && ! -f $CONFDIR/txt/skip.txt ]]; then
    if [[ $PLAY_ELAPSEDTIME -gt 15 ]]; then                                       # If ffmpeg only played for a few seconds, that's not a play worth recording.
      record_resumed_play
    fi
  fi

else
  INVALIDFLAC=1
  clear; source "$CONFDIR/bin/giomenudraw.sh" short
  echo ""
  echo -e "  A non-existent or invalid FLAC file has been detected."
  echo -e "  Quitting attempts to play."
  echo ""
  read -n 1 -s -r -p "  Press a key to return to the main menu."
fi
}

function record_resumed_play {
f=$(find "$GPLAYDIR" -maxdepth 1 -name "*.flac" | sort | head -n 1)
PLAYARTIST=$($METAFLAC $UTFCHARS --show-tag=Artist "$f" | $SEDPROG 's/.*=//g' 2>/dev/null)
PLAYALBUM=$($METAFLAC $UTFCHARS --show-tag=Album "$f" | $SEDPROG 's/.*=//g' 2>/dev/null)
PLAYGENRE=$($METAFLAC $UTFCHARS --show-tag=Genre "$f" | $SEDPROG 's/.*=//g' 2>/dev/null)
PLAYPERFORMER=$($METAFLAC $UTFCHARS --show-tag=Performer "$f" | $SEDPROG 's/.*=//g' 2>/dev/null)

PLAYDATE=$(date)
OS=$(cat /etc/os-release | $GREPPROG -w NAME= | gawk -F "=" '{print $2}' | $SEDPROG "s/\"//g" 2>/dev/null)
if [ -z "$OS" ]; then
  PRODUCT_NAME=$(sw_vers -productName)
  PRODUCT_VERSION=$(sw_vers -productVersion)
  case "${PRODUCT_VERSION%%.*}" in
	27) CODE_NAME="Golden Gate";;
    26) CODE_NAME="Tahoe";;
    15) CODE_NAME="Sequoia";;
    14) CODE_NAME="Sonoma" ;;
    13) CODE_NAME="Ventura" ;;
    12) CODE_NAME="Monterey" ;;
    11) CODE_NAME="Big Sur" ;;
    10) CODE_NAME="Catalina" ;;
    *) CODE_NAME="Unknown" ;;
  esac
  OS="$PRODUCT_NAME $CODE_NAME"
fi
DEVICE=$(hostname)
CURDATETIME=$(date '+%F %H:%M:%S')
PLAYHASHVALUE=$(echo -n "$PLAYARTIST$PLAYALBUM$PLAYDATE" | $MD5PROG | gawk '{print $1}')                  # Must be computed on the raw value of the ARTIST/ALBUM tag data, before mucking with them for SQL insert reasons
RECHASHVALUE=$(echo -n "$PLAYARTIST$PLAYALBUM" | $MD5PROG | gawk '{print $1}')                            # Must be computed on the raw value of the ARTIST/ALBUM/DATE tag data, before mucking with them for SQL insert reasons

PLAYARTIST=$(echo "$PLAYARTIST" | $SEDPROG "s/'/\'\'/g" 2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)             				# Strips out semicolons and turns single quotes into double single quotes (otherwise SQL breaks on the insert)
PLAYALBUM=$(echo "$PLAYALBUM" | $SEDPROG "s/'/\'\'/g" 2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)               				
PLAYGENRE=$(echo "$PLAYGENRE" | $SEDPROG "s/'/\'\'/g" 2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)               				
PLAYPERFORMER=$(echo "$PLAYPERFORMER" | $SEDPROG "s/'/\'\'/g" 2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)       				
ALBUMDIR=$(echo "$albumdir" | $SEDPROG "s/'/\'\'/g" 2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)                 				
FOLDERNAME=$(gbasename "$ALBUMDIR")

# Keep trying to record the play for up to 30 seconds before abandoning
STARTTIME=$(date +%s)
until "${PROCONN[@]}" -e "insert into global_plays (playdate, foldername, composer, composition, genre, performer, duration, devicename, os_type, rechashvalue, playhashvalue) values ('$CURDATETIME','$FOLDERNAME','$PLAYARTIST','$PLAYALBUM','$PLAYGENRE','$PLAYPERFORMER','$PLAYLENGTH', '$DEVICE', '$OS', '$RECHASHVALUE','$PLAYHASHVALUE')" 2>/dev/null &&
      "${PROCONN[@]}" -e "delete from global_pauses where rechashvalue='$RECHASHVALUE'" 2>/dev/null
do
  if [[ $(($(date +%s) - STARTTIME)) -ge 30 ]]; then
    break
  fi
  sleep 5
done
}

pick_recording
if [[ $NOPAUSED -eq 0 ]]; then
  clear; source "$CONFDIR/bin/giomenudraw.sh" playing
  play_resume
  rm -f "$CONFDIR/txt/giocoso-tracklist.txt" 2>/dev/null
fi
