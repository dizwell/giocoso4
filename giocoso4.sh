#!/usr/bin/env bash
# ==============================================================================================================
# Giocoso is a gapless, trackless, optionally-randomising command-line FLAC player for Linux, Windows and macOS.
#
# Full documentation is available at:
# https://bbritten.com/software/giocoso4
#
# Copyright © H. Rogers 2019-2026
# Version 4.00 - 30th December 2026 ?
#
# This program is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software Foundation,
# version 2.0 only of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# A copy of the GNU General Public License can be displayed by running the program
# and selecting the Administration menu, Option 5.
#
# The `tput` wrapper used throughout Giocoso is taken from https://github.com/bahamas10/bash-tput
# with grateful thanks to Dave Eddy and much appreciation: it speeds things up immensely!
#
# Version History
# ---------------
# 1.00  Initial Release                                                15.07.21 + 14 point releases
# 2.00  Second Release                                                 22.07.22 + 4 point releases
# 3.00  Third Release                                                  22.11.23 + 23 point releases
# 4.00  Fourth Release - initial release                               30.12.26
# 
# ==============================================================================================================
DIRECT_PLAY=0 COUNTFLAC=0 PLAYS=1 SEARCHCOUNT=0 CONFDIR="$HOME/.local/share/giocoso4"
COPYRIGHT="2019-2026"                             # Copyright years, shown on every screen that displays them

function parse_config {
source "$CONFDIR/bin/gioparse.sh"
}

function exit_program {
# Giocoso can play music, or it can do 'other stuff'. If a play-music session quits, it should tidy up after itself.
# If an 'other stuff' (reporting, control etc) session quits, it should just quit and not monkey about with files on displaywork
# Play-music sessions, uniquely, set CONTROL_ONLY=0, so if CONTROL_ONLY is null or is non-zero, just quit.
# If CONTROL_ONLY=0, then we do tidy-up.
if [[ -z $CONTROL_ONLY ]]; then CONTROL_ONLY=2; fi
if [[ $CONTROL_ONLY -eq 0 ]]; then                        # File deletions etc only happen when a playing session quits, not when a non-playing session quits
  rm -f "$CONFDIR/txt/autostop.txt" >/dev/null 2>&1; rm -f "$CONFDIR/txt/terminate.txt" >/dev/null 2>&1
  rm -f "$CONFDIR/txt/skip.txt" >/dev/null 2>&1 ; rm -f "$CONFDIR/txt/repeat.txt" >/dev/null 2>&1
  rm -f "$CONFDIR/txt/histogram.txt" >/dev/null 2>&1; rm -f "$CONFDIR/txt/caption.txt" >/dev/null 2>&1
  rm -f "$CONFDIR/txt/searchfilter.txt" >/dev/null 2>&1
  rm -f "$CONFDIR/txt/giocoso-tracklist.txt" >/dev/null 2>&1; rm -f "$CONFDIR/txt/nowplaying.txt" >/dev/null 2>&1
  rm -f "$CONFDIR/txt/mgioplay.txt" >/dev/null 2>&1
  echo "" > "$CONFDIR/txt/newplay.txt"
  $MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
fi

# The next lines happen, regardless of what CONTROL_ONLY is set to...
pkill -P $$              # Kill off any child processes of the current session: that will include minig, ffmpeg and standalone album art windows.
tput sgr0; tput cvvis; reset; clear
exit 0
}

trap exit_program TERM      # Trap to quit nicely if the terminal is closed by clicking 'X' icon in window titlebar
trap exit_program SIGHUP    # Same thing, different signal
trap exit_program INT       # Trap to prevent Ctrl+C from working

function gmenuoptions {
tput civis
source "$CONFDIR/bin/giomenudraw.sh"
source "$CONFDIR/bin/giomenuoptions.sh"
}

function clearscreen {
if [[ $DIRECT_PLAY -eq 0 ]]; then
  source "$CONFDIR/bin/giomenudraw.sh"
else
  source "$CONFDIR/bin/giomenudraw.sh" minig
fi
}

function compute_duration {
local f track_duration_float track_duration_int      # Scratch values only: don't leak into (or overwrite) the caller's variables
PLAYLENGTH=0 PLAYSECS=0

f=$(printf '%s\n' "$PLAYDIR"/*.flac | head -1)
DURCOMPOSER=$($METAFLAC $UTFCHARS --show-tag=Artist "$f" | $SEDPROG s/.*=//g)
DURCOMPOSITION=$($METAFLAC $UTFCHARS --show-tag=Album "$f" | $SEDPROG s/.*=//g)    
DURRECHASH=$(echo -n "$DURCOMPOSER$DURCOMPOSITION" | $MD5PROG | gawk '{print $1}')

# See if there is an entry in the database for the recording being played.
# If so, retrieve the DURATION value from the database.
SQLSTMT="select ifnull(duration,0) from global_recordings where rechashvalue='$DURRECHASH'"
TOTALDUR=$("${PROCONN[@]}" -N -B -e "$SQLSTMT" 2>/dev/null)
TOTALDUR=$(round $TOTALDUR/1 0)                               # Converts the returned value to an integer number of seconds
PLAYSECS=$TOTALDUR
PLAYLENGTH=$($DATEPROG -d@$TOTALDUR -u +%H:%M:%S)               # duration of current recording, in hh:mm:ss format

# If there is no matching database recording, then TOTALDUR will be zero and duration
# can be computed ab initio
TOTALDUR=$(awk '{$0=int($0)}1' <<< "$TOTALDUR")                     # Needed to turn a string into an integer for assessment as to whether it's zero or not
if [[ $TOTALDUR -eq 0 ]]; then
  for f in "$PLAYDIR"/*.flac; do
    track_duration_float=$($FFPROBE -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f")
	track_duration_int=$(printf "%.0f\n" "$track_duration_float")
	TOTALDUR=$((TOTALDUR+track_duration_int))
  done
  PLAYSECS=$TOTALDUR
  PLAYLENGTH=$($DATEPROG -d@$TOTALDUR -u +%H:%M:%S)                  	# duration of current recording, in hh:mm:ss format  
fi
}

function sixel_graphics {
if [[ $DIRECT_PLAY -eq 0 ]]; then 
  tput cup 5 57
  "$SIXEL" "$CONFDIR/art/albumart.jpg" 2>/dev/null										        # Display in-terminal as-is
fi
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

f=$(find "$PLAYDIR" -maxdepth 1 -name "*.flac" | sort | head -n 1)
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

function last_play {
# Determine whether the selected recording has been played before and, if so, how many times.
f=$(find "$PLAYDIR" -maxdepth 1 -name "*.flac" | sort | head -n 1)
PLAYARTIST=$($METAFLAC $UTFCHARS --show-tag=Artist "$f" | $SEDPROG s/.*=//g)
PLAYALBUM=$($METAFLAC $UTFCHARS --show-tag=Album "$f" | $SEDPROG s/.*=//g)
RECHASHVALUE=$(echo -n "$PLAYARTIST$PLAYALBUM" | $MD5PROG | gawk '{print $1}')
PLAYARTIST=$(echo "$PLAYARTIST" | $SEDPROG "s/'/\'\'/g" | $SEDPROG "s/;//g")   # Strips out semicolons and turns single quotes into double single quotes (otherwise SQL breaks on the insert)
PLAYALBUM=$(echo "$PLAYALBUM" | $SEDPROG "s/'/\'\'/g" | $SEDPROG "s/;//g")   # Strips out semicolons and turns single quotes into double single quotes (otherwise SQL breaks on the insert)
SQLSTMT="select count(*) from global_plays where rechashvalue='$RECHASHVALUE'"
PREVIOUSPLAYS=$("${PROCONN[@]}" -N -B -e "$SQLSTMT" 2>/dev/null)
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
}

function start_playback {
# This bit does the actual playing of the virtual playlist, adding one second of silence on to the end, to ensure the playback completes properly.
PLAY_OFFSET=0
PLAYSTART_CLOCKTIME=$(date +%s)
touch "$CONFDIR/txt/nowplaying.txt"
    
if [[ $(uname -a) == *"Darwin"* ]]; then
  if [[ $FORCE_PULSE -eq 1 ]]; then 
    PULSE_SERVER=$PULSESERVER $FFMPEG -stats_period 1 -f concat -safe 0 -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f pulse "default?async=1" |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
  else
    $FFMPEG -stats_period 1 -f concat -safe 0 -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f audiotoolbox - |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
  fi
elif [[ $(uname -a) == *"microsoft"* ]]; then
  AUDIODEVICE="PulseAudio"
  if [[ $FORCE_PULSE -eq 1 ]]; then
    PULSE_SERVER=$PULSESERVER $FFMPEG -stats_period 1 -f concat -safe 0 -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f pulse - |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
  else
    $FFMPEG -stats_period 1 -f concat -safe 0 -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f pulse - |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
  fi
else
  if [[ $FORCE_PULSE -eq 1 ]]; then
    AUDIODEVICE="PulseAudio"
    # Do this if running on Linux but use of Pulseaudio is forced in configuration file
    PULSE_SERVER=$PULSESERVER $FFMPEG -stats_period 1 -f concat -safe 0 -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f pulse - |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
  else
    # Do this if running on Linux and Pulseaudio hasn't been forced on
    $FFMPEG -stats_period 1 -f concat -safe 0 -i "$CONFDIR/txt/giocoso-tracklist.txt" -af "$AF_FILTER" -max_muxing_queue_size 4096 -f alsa "$AUDIODEVICE" |& gawk -v RS="\r" -v FS='[= ]' 'NR > 1 && /time=/ {print $4; fflush("/dev/stdout")}' > "$CONFDIR/txt/playcounter.txt" & source "$CONFDIR/bin/giocount.sh" "${PLAYSECS%.*}"
  fi
fi
}

function end_playback {
# Clean Up after Play Completes
rm -f "$CONFDIR/txt/nowplaying.txt" 2>/dev/null
rm -f "$CONFDIR/txt/mgioplay.txt" 2>/dev/null
echo "" > "$CONFDIR/txt/newplay.txt"
$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
  
if [[ ! -f "$CONFDIR/txt/terminate.txt" && ! -f "$CONFDIR/txt/skip.txt" ]]; then
  if [[ $PLAY_ELAPSEDTIME -gt 15 ]]; then                                       # If ffmpeg only played for a few seconds, that's not a play worth recording.
    record_play
  fi
fi
}

function extract_metadata {
if [[ $($METAFLAC $UTFCHARS --export-picture-to="$CONFDIR/art/albumart.jpg" "$f" 2>&1 | $GREPPROG "ERROR" | wc -l) -gt 0 ]]; then
  cp "$CONFDIR/art/genericalbumart.jpg" "$CONFDIR/art/albumart.jpg"
else
  $METAFLAC $UTFCHARS --export-picture-to="$CONFDIR/art/albumart.jpg" "$f" >/dev/null 2>&1
fi

displaydate=$($METAFLAC $UTFCHARS --show-tag=Year "$f" | $SEDPROG s/.*=//g); if [[ -z $displaydate ]]; then displaydate=$($METAFLAC $UTFCHARS --show-tag=Date "$f" | $SEDPROG s/.*=//g); fi
displaygenre=$($METAFLAC $UTFCHARS --show-tag=Genre "$f" | $SEDPROG s/.*=//g)
displaycomment=$($METAFLAC $UTFCHARS --show-tag=Comment "$f" | $SEDPROG s/.*=//g); THISCOMMENT="$displaycomment"
if [[ ${#displaycomment} -gt 330 ]]; then displaycomment="${displaycomment::330}…"; fi
displaycomp=$($METAFLAC $UTFCHARS --show-tag=Artist "$f" | $SEDPROG s/.*=//g); THISARTIST="$displaycomp"
displaywork=$($METAFLAC $UTFCHARS --show-tag=Album "$f" | $SEDPROG s/.*=//g); THISALBUM="$displaywork"
THISDISTINGUISHED_ARTIST=$($METAFLAC $UTFCHARS --show-tag=Performer "$f" | $SEDPROG s/.*=//g)
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
}

function generate_tracklist {
for f in *.flac; do                    # Main loop around all FLACs to generate a 'virtual' playlist for gapless playback
  filename=$(gbasename "$f")
  albumdir=$(gdirname "$PLAYDIR"/"$f")
  echo "file #$PLAYDIR/$filename#" >> "$CONFDIR/txt/giocoso-tracklist.txt"
done
}

function voice_to_lang {
# This function takes the global_phonemes voice names, which are only valid for
# macOS's "say" utility, and converts them into a national language code, which
# Linux's espeak-ng can interpret/use correctly.	
case "$1" in
  Ellen)    VOICELANG="nl"  ;;
  Tingting) VOICELANG="cmn" ;;
  Zuzana)   VOICELANG="cs"  ;;
  Alva)     VOICELANG="da"  ;;
  Daniel)   VOICELANG="en"  ;;
  Satu)     VOICELANG="fi"  ;;
  Thomas)   VOICELANG="fr"  ;;
  Anna)     VOICELANG="de"  ;;
  Melina)   VOICELANG="el"  ;;
  Tünde)    VOICELANG="hu"  ;;
  Alice)    VOICELANG="it"  ;;
  Kyoko)    VOICELANG="en"  ;;		# espeak really does not do English typing of Japanese names at all well, so best leave it in English.
  Zosia)    VOICELANG="pl"  ;;
  Joana)    VOICELANG="pt"  ;;
  Milena)   VOICELANG="ru"  ;;
  Mónica)   VOICELANG="es"  ;;
  Yelda)    VOICELANG="tr"  ;;
  *) VOICELANG="en" ;;
esac
}

function announce_play {
if [[ ${ANNOUNCEPLAY^^} == "YES" ]]; then

  # Play some 'actively silent' sound to wake up the DAC before throwing voices at it	  
  if [[ $(uname -a) == *"Darwin"* ]]; then
    if [[ $FORCE_PULSE -eq 1 ]]; then 
      PULSE_SERVER=$PULSESERVER "$FFMPEG" -i "$CONFDIR/art/silence.flac" -f pulse - > /dev/null 2>&1
    else
      "$FFMPEG" -i "$CONFDIR/art/silence.flac" -f audiotoolbox - > /dev/null 2>&1
    fi
  elif [[ $(uname -a) == *"microsoft"* ]]; then
    AUDIODEVICE="PulseAudio"
  	if [[ $FORCE_PULSE -eq 1 ]]; then
  	  PULSE_SERVER=$PULSESERVER "$FFMPEG" -i "$CONFDIR/art/silence.flac" -f pulse - > /dev/null 2>&1
  	else
  	  "$FFMPEG" -i "$CONFDIR/art/silence.flac" -f pulse - > /dev/null 2>&1
  	fi
  else
  	if [[ $FORCE_PULSE -eq 1 ]]; then
  	  AUDIODEVICE="PulseAudio"
  	  # Do this if running on Linux but use of Pulseaudio is forced in configuration file
  	  PULSE_SERVER=$PULSESERVER "$FFMPEG" -i "$CONFDIR/art/silence.flac" -f pulse - > /dev/null 2>&1
  	else
  	  # Do this if running on Linux and Pulseaudio hasn't been forced on
  	  "$FFMPEG" -i "$CONFDIR/art/silence.flac" -f alsa "$AUDIODEVICE" > /dev/null 2>&1
  	fi
  fi
	  
  if [[ $(uname -a) == *"Darwin"* ]]; then  
    if command -v say >/dev/null 2>&1; then
  	  # Voice announcements look at "phrase, voice, phoneme". There's meant to be an exact match on composer: Daniel will always announce them
  	  # Compositions are generally announced by Daniel, too: except, if the composition name is obviously in French, German or Italian (other languages are available)
  	  # and the phoneme table has explcitly said a foreign voice should announce them, because transliterating them to English produces too
  	  # grotesque a result, then that other voice will do the composition name announcement.
	  
  	  SQLDISPLAYCOMP="${displaycomp//\'/\'\'}"
  	  SQLFULLWORKNAME="${FULLWORKNAME//\'/\'\'}"
	  SOUNDCOMPOSER=$("${PROCONN[@]}" -N -B -e "select ifnull(phoneme, phrase) from phonemes where phrase='$SQLDISPLAYCOMP'" 2>/dev/null)
  	  VOICECOMPOSER=$("${PROCONN[@]}" -N -B -e "select ifnull(voice, 'Daniel') from phonemes where phrase='$SQLDISPLAYCOMP'" 2>/dev/null)
  	  SOUNDCOMPOSITION=$("${PROCONN[@]}" -N -B -e "select ifnull(phoneme, phrase) from phonemes where phrase='$SQLFULLWORKNAME'" 2>/dev/null)
  	  VOICECOMPOSITION=$("${PROCONN[@]}" -N -B -e "select ifnull(voice, 'Daniel') from phonemes where phrase='$SQLFULLWORKNAME'" 2>/dev/null)
		
  	  if [[ -z $SOUNDCOMPOSER || -z $SOUNDCOMPOSITION ]]; then
  	    :
  	  else	
	    # Some exotic voices differ on different versions of macOS, so check the required voice
  	    # is actually present and default to 'Daniel' if not
  	    if ! say -v '?' | awk '{print $1}' | grep -Fxq "$VOICECOMPOSER"; then
  	      VOICECOMPOSER="Daniel"
  	    fi
	  
  	    if ! say -v '?' | awk '{print $1}' | grep -Fxq "$VOICECOMPOSITION"; then
  	      VOICECOMPOSITION="Daniel"
  	    fi

        # Now do the initial announcement (always as Daniel), with a pause to let a DAC wake up
        say -v Daniel -r $VSPEED "[[slnc 400]] About to play [[slnc 10]]"

        # And now announce the reset of the composer/composition combo
  	    # If Daniel is announcing, he uses apostrophes. If it's anyone else, they don't	  
  	    if [[ $VOICECOMPOSER == "Daniel" ]]; then
  	      say -v "$VOICECOMPOSER" -r $VSPEED "[[slnc 50]] $SOUNDCOMPOSER$displayapostrophe" 2>/dev/null
        else
          say -v "$VOICECOMPOSER" -r $VSPEED "[[slnc 50]] $SOUNDCOMPOSER" 2>/dev/null								
  	    fi
	  
  	    say -v "$VOICECOMPOSITION" -r $VSPEED "[[slnc 50]] $SOUNDCOMPOSITION" 2>/dev/null
	  
  	    # A final pause to make sure the announcement doesn't over-sound the play
  	    sleep 1
  	  fi   
    fi
  else
    # For Linux-based systems, use the espeak-ng engine instead.	
    SQLDISPLAYCOMP="${displaycomp//\'/\'\'}"
    SQLFULLWORKNAME="${FULLWORKNAME//\'/\'\'}"
    SOUNDCOMPOSER=$("${PROCONN[@]}" -N -B -e "select ifnull(phoneme, phrase) from phonemes where phrase='$SQLDISPLAYCOMP'" 2>/dev/null)
    VOICECOMPOSER=$("${PROCONN[@]}" -N -B -e "select ifnull(voice, 'Daniel') from phonemes where phrase='$SQLDISPLAYCOMP'" 2>/dev/null)
    SOUNDCOMPOSITION=$("${PROCONN[@]}" -N -B -e "select ifnull(phoneme, phrase) from phonemes where phrase='$SQLFULLWORKNAME'" 2>/dev/null)
    VOICECOMPOSITION=$("${PROCONN[@]}" -N -B -e "select ifnull(voice, 'Daniel') from phonemes where phrase='$SQLFULLWORKNAME'" 2>/dev/null)	

    if [[ -z $SOUNDCOMPOSER || -z $SOUNDCOMPOSITION ]]; then
      :
    else	
      # Convert MacOS voice names into nationalities for the composer name
  	  voice_to_lang "$VOICECOMPOSER"
	  
      # Now do the initial announcement (always in English), with a pause to let a DAC wake up
  	  espeak-ng -m -v en -s "$VSPEED" "<break time='400ms'/>About to play<break time='10ms'/>"
      
      # And now announce the reset of the composer/composition combo
      # If Daniel is announcing, he uses apostrophes. If it's anyone else, they don't	  
      if [[ $VOICECOMPOSER == "Daniel" ]]; then
  	    espeak-ng -m -v "$VOICELANG" -s "$VSPEED" "<break time='50ms'/>$SOUNDCOMPOSER$displayapostrophe" 2>/dev/null  
      else
  	    espeak-ng -m -v "$VOICELANG" -s "$VSPEED" "<break time='50ms'/>$SOUNDCOMPOSER" 2>/dev/null  						
      fi

      # Convert MacOS voice names into nationalities for the composition name:
      voice_to_lang "$VOICECOMPOSITION"
      espeak-ng -m -v "$VOICELANG" -s "$VSPEED" "<break time='50ms'/>$SOUNDCOMPOSITION" 2>/dev/null
  
      # A final pause to make sure the announcement doesn't over-sound the play
      sleep 1
    fi   	
  fi		
fi 
}

function display_data {
local i counter lastline_reached                      								# Loop scratch values
local -a composition performers                        								# Caption lines for the work and the performers; used only within this function
$SEDPROG -i "s/'/'\\\''/g" "$CONFDIR/txt/giocoso-tracklist.txt"             		# Parse tracklist and replace single quotes with escaped version
$SEDPROG -i "s/#/'/g" "$CONFDIR/txt/giocoso-tracklist.txt"

if [[ $DIRECT_PLAY -eq  0 ]]; then 
  source "$CONFDIR/bin/gioart.sh" "$displaycomp" "$displaywork"				# Create a displayable piece of album art+caption
  WORKNAMELength=${#FULLWORKNAME}; WORKNAMELines=$(( (WORKNAMELength + 45) / 45 ))	# Some maths to work out how many lines something takes, assuming a display width of 45 characters.
  tput cup  5 4; echo -en "                                              "
  tput cup 18 4; echo -en "                                              "
  tput cup 19 4; echo -en "                                              "
  tput cup 20 4; echo -en "                                              "
  tput cup 21 4; echo -en "                                              "
  tput cup 22 4; echo -en "                                              "
  tput cup 23 4; echo -en "                                              "
     
  tput cup 5 4; tput setaf "$MAINTEXT"; echo -en "$displaycomp$displayapostrophe"
  tput cup 17 0; tput setaf "$DRAWLINES"; echo -en "├─────────────────────────────────────────────────┤"
  tput cup 18 4; tput setaf "$MAINTEXT"; echo -en "Days since last played: "; tput setaf "$INFOTEXT"; echo -en "$LASTPLAYED : $LASTCOMPOSERPLAYED"
  tput cup 19 4; tput setaf "$MAINTEXT"; echo -en "Recording Year: "; tput setaf "$INFOTEXT"; echo -en "$displaydate"
  tput cup 20 4; tput setaf "$MAINTEXT"; echo -en "Genre: "; tput setaf "$INFOTEXT"; echo -en "$displaygenre"
  tput cup 21 4; tput setaf "$MAINTEXT"; echo -en "Audio Tech: "; tput setaf "$INFOTEXT"; echo -en "$displayhertz/$displaydepth"
  tput cup 22 4; tput setaf "$MAINTEXT"; echo -en "Previous plays: "; tput setaf "$INFOTEXT"; echo -en "$PREVIOUSPLAYS"
  tput cup 23 4; tput setaf "$MAINTEXT"; echo -en "ReplayGain Applied: "; tput setaf "$INFOTEXT"; echo -en "$DISPLAYRPG"

  readarray -t composition < <(echo "$FULLWORKNAME" | fmt -w 45)
  counter=0
  for i in "${!composition[@]}"; do
    ((counter++))
    tput cup $((5 + counter )) 4; tput setaf $INFOTEXT; echo -en "\033[1m\e[3m${composition[$i]}\e[0m\033[0m"; tput sgr0;
    lastline_reached=$counter
  done

  readarray -t performers < <(echo "$displaycomment" | fmt -w 45)
  counter=0
  for i in "${!performers[@]}"; do
    ((counter++))
    tput cup $(( 6 + $counter + $lastline_reached )) 4; echo -en "${performers[$i]}"
  done

  erase_logo
  sixel_graphics

  TERMTITLE="$displaycomp - $displaywork - $THISDISTINGUISHED_ARTIST"; TERMTITLE=${TERMTITLE:0:99}			# Usually not needed, but put a limit on composer+composition name for display purposes,  in case the terminal doesn't truncate it itself
  if [[ $(uname -a) == *"Darwin"* ]]; then 
    echo -ne "\033]0; Now playing: $TERMTITLE \007"
  else
    echo -en "\033]0; Now playing: $TERMTITLE \007\c"						# Setting terminal's titlebar
  fi
else    # True for minimal player
  source "$CONFDIR/bin/gioart.sh" "$displaycomp" "$displaywork"				# Create a displayable piece of album art+caption
  WORKNAMELength=${#FULLWORKNAME}; WORKNAMELines=$(( (WORKNAMELength + 45) / 45 ))	# Some maths to work out how many lines something takes, assuming a display width of 45 characters.
  tput cup  5 4; echo -en "                                              "
  tput cup 17 4; echo -en "                                              "
  tput cup 18 4; echo -en "                                              "
  tput cup 19 4; echo -en "                                              "
  tput cup 20 4; echo -en "                                              "
  tput cup 21 4; echo -en "                                              "
  tput cup 22 4; echo -en "                                              "
  tput cup 23 4; echo -en "                                              "
     
  tput cup 5 4; tput setaf "$MAINTEXT"; echo -en "$displaycomp$displayapostrophe"
  tput cup 16 0; tput setaf "$DRAWLINES"; echo -en "├─────────────────────────────────────────────────┤"
  tput cup 18 4; tput setaf "$MAINTEXT"; echo -en "Days since last play: "; tput setaf "$INFOTEXT"; echo -en "$LASTPLAYED"
  tput cup 19 4; tput setaf "$MAINTEXT"; echo -en "Recording Year: "; tput setaf "$INFOTEXT"; echo -en "$displaydate"
  tput cup 20 4; tput setaf "$MAINTEXT"; echo -en "Genre: "; tput setaf "$INFOTEXT"; echo -en "$displaygenre"
  tput cup 21 4; tput setaf "$MAINTEXT"; echo -en "Audio Tech: "; tput setaf "$INFOTEXT"; echo -en "$displayhertz/$displaydepth"
  tput cup 22 4; tput setaf "$MAINTEXT"; echo -en "Previous plays: "; tput setaf "$INFOTEXT"; echo -en "$PREVIOUSPLAYS"
  tput cup 23 4; tput setaf "$MAINTEXT"; echo -en "ReplayGain Applied: "; tput setaf "$INFOTEXT"; echo -en "$DISPLAYRPG"

  readarray -t composition < <(echo "$FULLWORKNAME" | fmt -w 45)
  counter=0
  for i in "${!composition[@]}"; do
    ((counter++))
    tput cup $((5 + counter )) 4; tput setaf $INFOTEXT; echo -en "\033[1m\e[3m${composition[$i]}\e[0m\033[0m"; tput sgr0;
    lastline_reached=$counter
  done

  readarray -t performers < <(echo "$displaycomment" | fmt -w 45)
  counter=0
  for i in "${!performers[@]}"; do
    ((counter++))
    tput cup $(( 5 + $counter + $lastline_reached )) 4; echo -en "${performers[$i]}"
  done

  TERMTITLE="$displaycomp - $displaywork - $THISDISTINGUISHED_ARTIST"; TERMTITLE=${TERMTITLE:0:99}			# Usually not needed, but put a limit on composer+composition name for display purposes,  in case the terminal doesn't truncate it itself
  if [[ $(uname -a) == *"Darwin"* ]]; then 
    echo -ne "\033]0; $TERMTITLE \007"
  else
    echo -en "\033]0; $TERMTITLE \007\c"						# Setting terminal's titlebar
  fi
fi
}

function perform_countdown {
local i input                                        # Loop counter and key press: scratch values only	
if [[ $COUNTDOWN -gt 0 && $PLAYS -gt 1 ]]; then
  for ((i=$COUNTDOWN; i >=0; i--)); do
    if [[ $DIRECT_PLAY -eq 0 ]]; then
      tput cup 25 4; tput sgr0; echo -en "                                                                                               "
      tput cup 25 4; tput setaf $LOGO; echo -en "Play of the next recording ($PLAYLENGTH) will start in $i seconds...";
    else
      tput cup 25 4; tput sgr0; echo -en "                                        "
      tput cup 25 4; tput setaf $LOGO; echo -en "Play will start in $i seconds...";
    fi
    tput cup 3 77; tput setaf 0; read -t 1 -rsn 1 input                             # Check to see if any control keys have been pressed
    if [[ ! -z $input ]]; then
      case $input in
        c|C ) break;;
      esac
    fi
    if [[ -f $CONFDIR/txt/countdown.txt ]]; then
      rm -f "$CONFDIR/txt/countdown.txt" 2>/dev/null
      break;
    fi
  done
  if [[ $DIRECT_PLAY -eq 0 ]]; then
    tput cup 25 4; tput sgr0; echo -en "                                                                                               "
  else
    tput cup 25 4; tput sgr0; echo -en "                                        "
  fi
fi
}

function play_music {
CONTROL_ONLY=0; VALIDDIR=0
if [[ -d $PLAYDIR ]]; then 
  VALIDDIR=1
  cd "$PLAYDIR"
  rm -f "$CONFDIR/txt/giocoso-tracklist.txt" >/dev/null 2>&1

  # Find the first file in the folder and check it's a valid FLAC. No point proceeding if not.
  f=$(find "$PLAYDIR" -maxdepth 1 -name "*.flac" | sort | head -n 1)
  if [[ -n "$f" ]] && file "$f" | grep -q 'FLAC audio'; then
    :
  else
    clear; source "$CONFDIR/bin/giomenudraw.sh" short
    tput setaf "$ALERT"  
    tput cup 9 4;   echo -e "A non-existent or invalid FLAC file has been detected."
    tput cup 10 4;  echo -e "Quitting attempts to play."
    tput cup 12 4;  read -n 1 -s -r -p "Press a key to return to the main menu."
    PLAYS=$MAXLOOPS   # The terminating condition for the plays-until-number_of_plays_per_cycle loop
    return
  fi
else
  return
fi

# So at this point, we know we're in a valid folder and with a valid FLAC. So we begin:
extract_metadata
generate_tracklist
compute_replaygain
last_play
display_data
perform_countdown
announce_play
start_playback
  POSTPLAY_CLOCKTIME=$(date +%s)
  PLAY_ELAPSEDTIME=$(( POSTPLAY_CLOCKTIME - PLAYSTART_CLOCKTIME ))              # Want to determine how long ffmpeg played music for
end_playback
}

function record_play {
f=$(find "$PLAYDIR" -maxdepth 1 -name "*.flac" | sort | head -n 1)
PLAYARTIST=$($METAFLAC $UTFCHARS --show-tag=Artist "$f" | $SEDPROG s/.*=//g)
PLAYALBUM=$($METAFLAC $UTFCHARS --show-tag=Album "$f" | $SEDPROG s/.*=//g)
PLAYGENRE=$($METAFLAC $UTFCHARS --show-tag=Genre "$f" | $SEDPROG s/.*=//g)
PLAYPERFORMER=$($METAFLAC $UTFCHARS --show-tag=Performer "$f" | $SEDPROG s/.*=//g)

PLAYDATE=$(date)
OS=$(cat /etc/os-release | $GREPPROG -w NAME= | gawk -F "=" '{print $2}' | $SEDPROG "s/\"//g")
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
COMPUTER=$(hostname)
CURDATETIME=$(date '+%F %H:%M:%S')
PLAYHASHVALUE=$(echo -n "$PLAYARTIST$PLAYALBUM$PLAYDATE" | $MD5PROG | gawk '{print $1}')                  # Must be computed on the raw value of the ARTIST/ALBUM tag data, before mucking with them for SQL insert reasons
RECHASHVALUE=$(echo -n "$PLAYARTIST$PLAYALBUM" | $MD5PROG | gawk '{print $1}')                            # Must be computed on the raw value of the ARTIST/ALBUM/DATE tag data, before mucking with them for SQL insert reasons

PLAYARTIST=$(echo "$PLAYARTIST" | $SEDPROG "s/'/\'\'/g" | $SEDPROG "s/;//g")             				# Strips out semicolons and turns single quotes into double single quotes (otherwise SQL breaks on the insert)
PLAYALBUM=$(echo "$PLAYALBUM" | $SEDPROG "s/'/\'\'/g" | $SEDPROG "s/;//g")               				# Strips out semicolons and turns single quotes into double single quotes (otherwise SQL breaks on the insert)
PLAYGENRE=$(echo "$PLAYGENRE" | $SEDPROG "s/'/\'\'/g" | $SEDPROG "s/;//g")               				# Strips out semicolons and turns single quotes into double single quotes (otherwise SQL breaks on the insert)
PLAYPERFORMER=$(echo "$PLAYPERFORMER" | $SEDPROG "s/'/\'\'/g" | $SEDPROG "s/;//g")       				# Strips out semicolons and turns single quotes into double single quotes (otherwise SQL breaks on the insert)
ALBUMDIR=$(echo "$albumdir" | $SEDPROG "s/'/\'\'/g" | $SEDPROG "s/;//g")                 				# Strips out semicolons and turns single quotes into double single quotes (otherwise SQL breaks on the insert)
FOLDERNAME=$(gbasename "$ALBUMDIR")

# Keep trying to record the play for up to 30 seconds before abandoning
STARTTIME=$(date +%s)
until "${PROCONN[@]}" -e "insert into global_plays (playdate, foldername, composer, composition, genre, performer, duration, devicename, os_type, rechashvalue, playhashvalue) values ('$CURDATETIME','$FOLDERNAME','$PLAYARTIST','$PLAYALBUM','$PLAYGENRE','$PLAYPERFORMER','$PLAYLENGTH', '$COMPUTER', '$OS', '$RECHASHVALUE','$PLAYHASHVALUE')" 2>/dev/null &&
      "${PROCONN[@]}" -e "delete from global_pauses where rechashvalue='$RECHASHVALUE'" 2>/dev/null
do
  if [[ $(($(date +%s) - STARTTIME)) -ge 30 ]]; then
    break
  fi
  sleep 5
done
}

function main {
clear
# Create a folder structure, if it doesn't already exist (and suppress errors if it does!)
mkdir -p "$CONFDIR" "$CONFDIR/txt" "$CONFDIR/bin" "$CONFDIR/db" "$CONFDIR/art" 2>/dev/null  

if [[ $(uname -a) == *"Darwin"* ]]; then 
  echo -ne "\033]0;Giocoso: The Classical Music Player\007"
else
  echo -en "\033]0;Giocoso: The Classical Music Player\007\c"						# Setting terminal's titlebar
fi

# Invoke a bunch of files that provide cross-program functionality
source "$CONFDIR/bin/giotput.sh"
source "$CONFDIR/bin/giooscheck.sh"
source "$CONFDIR/txt/programvariables.txt"
FFNAME="${FFMPEG##*/}"                       # Just the program's name (eg ffmpeg-macos-arm64): it is what ps, pgrep and pkill look for
source "$CONFDIR/bin/giofunctions.sh"
source "$CONFDIR/bin/giospin.sh"

# Apply any parameters from the Configuration File
parse_config                                                                                            

for i in "$@"; do
case $i in
  --backup)
    source "$CONFDIR/bin/giobkpdb.sh" backup noprompt; exit;;
  --fastrefresh)
    source "$CONFDIR/bin/giorefreshdb.sh" "$1" fast; exit;;
  --fullrefresh) 
    source "$CONFDIR/bin/giorefreshdb.sh" "$1" full; exit;;
  --play)
    DIRECT_PLAY=1
esac
done
    
# Launch the program and decide whether to display full-fat Giocoso or the minig play controller
if [[ $DIRECT_PLAY -eq 0 ]]; then
  tput civis; printf '\e[8;28;103t' 	# Setting terminal virtual size to 103x28, regardless of what it's actually set to
  clear; gmenuoptions play
else
  tput civis; printf '\e[8;28;52t' 	# Setting terminal virtual size to 52x28, regardless of what it's actually set to
  clear; gmenuoptions minig
fi
exit_program
}

main "$@"
# ===============================================================================================================
# Thank you for using Giocoso. I hope it helps you (re)discover the less-played corners of your music collection.
# ===============================================================================================================
