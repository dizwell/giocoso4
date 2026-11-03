#!/usr/bin/env bash
####################################################################
#
# giocount: routine for counting/displaying time during plays.
# Also responsible for responding appropriately to pause, stop,
# skip and resume control signals passed to a playing session.
#
# Passed parameters: $1=Duration of recording in seconds
#
####################################################################
rm -f "$CONFDIR/txt/autostop.txt" "$CONFDIR/txt/terminate.txt" "$CONFDIR/txt/repeat.txt" 2>/dev/null
STARTEDPLAYING=$($DATEPROG +'%H:%M:%S')             # Invariant 'now' in hh:mm:ss format, indicating when this play started
PID=$(pgrep -f "$FFNAME -stats_period 1")            # Process ID of the playing session
unset ENDING_TIME
OPENER=xdg-open; [[ $OSFAMILY == *MACOS* ]] && OPENER=open

ORIG_STTY=$(stty -g)
stty -echo -icanon time 0 min 0

function convert_from_secs {
((h=${1}/3600))
((m=(${1}%3600)/60))
((s=${1}%60))
printf "%02d:%02d:%02d\n" $h $m $s
}

function convert_to_secs {
# Turns hh:mm:ss into seconds, which it returns in REPLY (not by echoing, so callers need no $( ) subshell).
# Anything that isn't a time, such as the 'N/A' or 'Video' that ffmpeg sometimes reports, gives 0.
# Pure Bash, so there is no awk to start. The 10# prefix stops 08 and 09 being read as (invalid) octal numbers.
if [[ $1 =~ ^[[:space:]]*([0-9]+):([0-9]+):([0-9]+) ]]; then
  REPLY=$(( 10#${BASH_REMATCH[1]} * 3600 + 10#${BASH_REMATCH[2]} * 60 + 10#${BASH_REMATCH[3]} ))
else
  REPLY=0
fi
}

DURATION="$1"                                                          # Invariant duration, expressed as seconds, passed from main program
DURATION_IN_HOURS=$(convert_from_secs $DURATION)                       # Invariant duration, expressed as hh:mm:ss
INVARIANT_ENDING_TIME=$($DATEPROG '+%T' --date="+$DURATION seconds")   # Invariant Ending Time, computed as now+duration, in hh:mm:ss format

# Control menu footer: the wording, order and spacing are all defined in footer_line (giofunctions.sh)
if [[ $DIRECT_PLAY -eq 0 ]]; then
  tput cup 1 57; echo -n "                                           "  # Clears the countdown display area
  tput cup 2 57; echo -n "                                           "
  tput cup 3 57; echo -n "                                           "
  footer_line; tput cup 25 4; echo -e "$FOOTER"                          # Displays the initial control menu
fi

# The mgioplay.txt file stores what's playing in plain text for easy use in other programs
# ===============================================================================================================
echo > "$CONFDIR"/txt/mgioplay.txt
echo "Composer@$THISARTIST" > "$CONFDIR"/txt/mgioplay.txt
echo "Recording@$THISALBUM" >> "$CONFDIR"/txt/mgioplay.txt
echo "Distinguishing@$THISDISTINGUISHED_ARTIST" >> "$CONFDIR"/txt/mgioplay.txt
echo "Performers@$THISCOMMENT" >> "$CONFDIR"/txt/mgioplay.txt
echo "Ending at@$INVARIANT_ENDING_TIME" >> "$CONFDIR"/txt/mgioplay.txt
echo "Previous plays@$PREVIOUSPLAYS" >> "$CONFDIR"/txt/mgioplay.txt
echo "ReplayGain Applied@$RPGAIN" >> "$CONFDIR"/txt/mgioplay.txt
echo "LastPlay@$LASTPLAYED">> "$CONFDIR"/txt/mgioplay.txt

if [[ $DIRECT_PLAY -eq 1 ]]; then tput cup 17 4; tput setaf "$MAINTEXT"; echo -en "Ending at: ";tput setaf "$INFOTEXT"; echo -en "$INVARIANT_ENDING_TIME"; fi

# This code turns what's playing into html, for use on a website with hot links, for example, to biographies
# ===============================================================================================================
# Build the website's composer URL fragment, identically on every OS: transliterate accents to plain
# ASCII, drop everything that isn't a letter, digit or space, then encode the spaces.
# iconv's //TRANSLIT only works under a UTF-8 locale, so use one if the session lacks it.
ICONVLOCALE="${LC_ALL:-${LC_CTYPE:-$LANG}}"
case "$ICONVLOCALE" in
  *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) : ;;
  *) if [[ $OSFAMILY == *"MACOS"* ]]; then ICONVLOCALE="en_GB.UTF-8"; else ICONVLOCALE="C.UTF-8"; fi ;;
esac
HTMLARTIST=$(printf '%s' "$THISARTIST" | LC_ALL="$ICONVLOCALE" iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null | $SEDPROG 's/[^a-zA-Z 0-9]//g; s/ /%20/g')
echo "<b>Composer</b>     :  <a href=\"https://bbritten.com/composer/$HTMLARTIST/\" target=\"_blank\">$THISARTIST</a>" > "$CONFDIR"/txt/newplay.txt		# At the start of a new play, output details of what's about to be played
echo "<b>Recording</b>    :  $THISALBUM" >> "$CONFDIR"/txt/newplay.txt	 # to a text file (which can subsequently be uploaded to a website, for example)
echo "<b>Performers</b>  :  $THISCOMMENT" >> "$CONFDIR"/txt/newplay.txt
echo "" >> "$CONFDIR"/txt/newplay.txt
echo "<b>Started at</b>   : $STARTEDPLAYING" >> "$CONFDIR"/txt/newplay.txt
echo "<b>Duration</b>      : $PLAYLENGTH" >> "$CONFDIR"/txt/newplay.txt
echo "<b>Ending at</b>     : $INVARIANT_ENDING_TIME" >> "$CONFDIR"/txt/newplay.txt
echo "<b>Audio Tech</b>  : $displaydepth/$displayhertz" >> "$CONFDIR"/txt/newplay.txt
echo "<b>Previous plays</b>  : $PREVIOUSPLAYS" >> "$CONFDIR"/txt/newplay.txt
echo "<b>Days since last play</b>  : $LASTPLAYED" >> "$CONFDIR"/txt/newplay.txt

# This is the main 'process play control commands loop
# ===============================================================================================================
while [[ -f $CONFDIR/txt/nowplaying.txt ]]; do
  PLAYCOUNTERTEXT=$(tail -1 "$CONFDIR/txt/playcounter.txt")
  [[ $PLAYCOUNTERTEXT == *:* ]] || PLAYCOUNTERTEXT=""                           # Same job grep ":" did: ignore lines with no colon
  read -r POSITION_IN_STREAM _ <<< "$PLAYCOUNTERTEXT"                           # First word only, whitespace trimmed (what echo $x did)
  POSITION_IN_STREAM=${POSITION_IN_STREAM:0:8}                                  # In hh:mm:ss, eg 00:01:14 after 1 minute 14 seconds of play
  convert_to_secs "$POSITION_IN_STREAM"; POSITION_IN_STREAM_IN_SECS=$REPLY      # In a simple number

  # So the next bit is quite involved. First off, the POSITION_IN_STREAM text can sometimes be 'N/A' or 'Video', at which point
  # the convert_to_secs function would return a 0. 'Good' times will return proper hh:mm:ss values. When the return is a 0, therefore,
  # we want a 00:00:00 fake 'placeholder' bit of text to display as the ENDING_TIME. Otherwise, we want a proper ENDING_TIME displayed.
  #
  # But secondly, we don't want a 'flickering ENDING_TIME'. That is, if this time through the loop the computed ending time is
  # a mere second or two different from before, who cares? Just ignore the difference and don't bother updating the display
  # or anything else. If the difference is *more* than 5 seconds, though, then yes we do want to update the display & files.
  #
  # The only slight catch is: we want to care about a difference *whether it's positive OR negative*. So how can we test for a
  # difference of 8 AND -8 equally well? Basic maths: square the difference and negative numbers become positives, and positives
  # stay positive. So: square the difference and if it's bigger than 25, we know the difference is more than 5 seconds either way.

  if [[ ! $POSITION_IN_STREAM_IN_SECS -eq 0 ]]; then
    TIME_LEFT_TO_PLAY_IN_SECS=$((DURATION - POSITION_IN_STREAM_IN_SECS))            # So, if good times are present, do maths...
    printf -v NOW_EPOCH '%(%s)T' -1                                                 # Seconds since 1970, right now
    printf -v NEW_ENDING_TIME '%(%T)T' $(( NOW_EPOCH + TIME_LEFT_TO_PLAY_IN_SECS )) # What the ending time would be if computed afresh right now
    convert_to_secs "$NEW_ENDING_TIME"; NEW_ENDING_SECS=$REPLY
    convert_to_secs "$ENDING_TIME"; OLD_ENDING_SECS=$REPLY
    ENDING_DIFFERENCE=$(( NEW_ENDING_SECS - OLD_ENDING_SECS ))
    ENDING_DIFFERENCE=$(( ENDING_DIFFERENCE * ENDING_DIFFERENCE ))                  # Squaring turns a negative difference into a positive one
    if [[ $ENDING_DIFFERENCE -gt 25 ]]; then                                        # More than 5 seconds out (5 squared = 25): adopt the new time
      ENDING_TIME=$NEW_ENDING_TIME
    fi                                                                              # Otherwise leave the displayed time alone, to avoid flicker
  else
    POSITION_IN_STREAM="00:00:00"                                                   # ...Otherwise, force a placeholder.
  fi
  
  printf -v CURSECS '%(%S)T' -1; CURSECS=$((10#$CURSECS))                           # Update the text files for progress reports, but only every 30 seconds
  if [[ $((CURSECS % 30)) -eq  0 ]]; then
    $SEDPROG -i "/.*Ending at.*/c \\<b\>Ending at\</b\>     : $ENDING_TIME" "$CONFDIR"/txt/newplay.txt 2>/dev/null
    $SEDPROG -i "/.*Ending at.*/c \\Ending at@\\$ENDING_TIME" "$CONFDIR"/txt/mgioplay.txt 2>/dev/null
  fi

  # We need to display numbers with appropriate padding. If we have 246 items to play, then the first one needs to display as 001, 
  # the second as 002 and so on. If we only have 15 items, then the first needs to be 01, the second 02 and so on. Therefore, the 
  # number of plays needs to be padded to be the length of the number of items to be played (which is in the LINESELECTIONS variable)
  # It is always the length of LINESELECTIONS which determines the padding to be applied to PLAYS.

  LINESELECTIONS=$((LINESELECTIONS))
  case ${#LINESELECTIONS} in
    1)  PADPLAYS=$PLAYS;;                        # If LENGTH = 1, then PLAYS is less than 10, therefore no need to zero pad anything
    2)  printf -v PADPLAYS "%02d" "$PLAYS";;   # If LENGTH = 2, then PLAYS might be 28, in which case, zero-pad plays to 2-digit long
    3)  printf -v PADPLAYS "%03d" "$PLAYS";;   # If LENGTH = 3, then PLAYS might be 249, therefore zero-pad plays to 3 digits long
    4)  printf -v PADPLAYS "%04d" "$PLAYS";;   # If LENGTH = 4, then PLAYS might be 2911, therefore zero-pad plays to 4 digits long
    *)  printf -v PADPLAYS "%05d" "$PLAYS";;   # In all other cases, zero-pad plays to 5 digits long
  esac

  if [[ $DIRECT_PLAY -eq 0 ]]; then
    SEARCHFILTER=""; read -r SEARCHFILTER 2>/dev/null < "$CONFDIR/txt/searchfilter.txt"
    if [[ $SEARCHFILTER == "Global Resume" ]]; then
      tput cup 1 57; tput setaf $MAINTEXT; echo -n "Selection:  "; tput setaf $INFOTEXT; echo -n "1"; tput setaf $MAINTEXT; echo -n " of "; tput setaf $INFOTEXT; echo -n "1 (Resumed Play)";
    else	  
       tput cup 1 57; tput setaf $MAINTEXT; echo -n "Selection:  "; tput setaf $INFOTEXT; echo -n "$PADPLAYS"; tput setaf $MAINTEXT; echo -n " of "; tput setaf $INFOTEXT; echo -n "$LINESELECTIONS";
    fi
    tput cup 2 57; tput setaf $MAINTEXT; echo -n "Played:     "; tput setaf $INFOTEXT; echo -n "${POSITION_IN_STREAM:0:8}"; tput setaf $MAINTEXT; echo -n " of "; tput setaf $INFOTEXT; echo -n "$DURATION_IN_HOURS"
    tput cup 3 57; tput setaf $MAINTEXT; echo -n "Ending at:  "; tput setaf $INFOTEXT; echo -n "$ENDING_TIME"
    tput cup 3 77; tput setaf 0
  fi
  read -t 0.95 -rsN 1 input                             # Check to see if any control keys have been pressed

  if [[ $input == $'\e' ]]; then
    seq="$input"
    while read -rsn1 -t 0.001 ch; do
     seq+="$ch"
    done
    input="$seq"
  fi
  
  if [[ ! -z $input ]]; then
    case $input in
      1|a|A ) tput cup 25 4; source "$CONFDIR/bin/giocontrol.sh" autostop;;
      2|t|T ) footer_line Terminate; tput cup 25 4; echo -e "$FOOTER"; source "$CONFDIR/bin/giocontrol.sh" terminate;;
      3|s|S ) footer_line Skip; tput cup 25 4; echo -e "$FOOTER"; source "$CONFDIR/bin/giocontrol.sh" skip;;
      4|r|R ) tput cup 25 4; source "$CONFDIR/bin/giocontrol.sh" repeat;;
  5|p|P|" " ) if [[ $DIRECT_PLAY -eq 0 ]]; then tput cup 25 4; source "$CONFDIR/bin/giocontrol.sh" pause; fi;;
        n|N ) if [[ $DIRECT_PLAY -eq 0 ]]; then source "$CONFDIR/bin/gioretnote.sh" edit_existing; fi;;
        F|f ) "$OPENER" "$PLAYDIR" 2>/dev/null ;;
        K|k ) if [[ -f $PLAYDIR/booklet.pdf ]]; then "$OPENER" "$PLAYDIR/booklet.pdf" 2>/dev/null; fi ;;
    Q|q|X|x ) exit_program;;
          * ) : ;;
    esac
  fi

  # Handling Autostops
  # ===============================================================================================================
  if [[ -f $CONFDIR/txt/autostop.txt ]]; then
    ASTOP=1
  else
    ASTOP=0
  fi

  # Handling Repeats
  # ===============================================================================================================
  if [[ -f $CONFDIR/txt/repeat.txt ]]; then
    RPEAT=1
  else
    RPEAT=0
  fi

  # Handling Terminations
  # ===============================================================================================================
  if [[ -f $CONFDIR/txt/terminate.txt ]]; then
    PID=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | awk '{print $2}')
    if [[ ! -z $PID ]]; then kill -9 $PID; fi
    pkill -f "$FFNAME -stats_period 1" >/dev/null 2>&1
    pkill -f "display -geometry" >/dev/null 2>&1
    break
  fi

  # Handling Skips
  # ===============================================================================================================
  if [[ -f $CONFDIR/txt/skip.txt ]]; then
    NOINTERCYCLE=1
    echo "" > "$CONFDIR"/txt/newplay.txt >/dev/null 2>&1
	$MAGICK -size "$ARTSIZE" canvas:transparent PNG32:"$CONFDIR/art/albumart.jpg" 2>/dev/null
    pkill -f "display -geometry" >/dev/null 2>&1
    rm -f "$CONFDIR/txt/skip.txt" >/dev/null 2>&1
    break
  fi

  # Handling multiple selected/toggled options at once. The toggles are Autostop and Repeat, in any
  # combination. Whichever are switched on get shown in reverse video in the footer. (Pause is not a toggle:
  # it records the position and ends the play, so there is never a 'paused' state to display.)
  FOOTER_ACTIVE=()
  [[ $ASTOP -eq 1 ]] && FOOTER_ACTIVE+=(Autostop)
  [[ $RPEAT -eq 1 ]] && FOOTER_ACTIVE+=(Repeat)
  footer_line "${FOOTER_ACTIVE[@]}"

  # Display the menu options, remembering to set foreground back to black so future keypresses remain invisible
  tput cup 25 4; tput setaf 10; echo -e "$FOOTER"; tput civis; tput cup 3 77; tput setaf 0

  # ffmpeg's PID doesn't change during a play, so only go looking for it (a search of the whole process table)
  # if we haven't got one yet, or the one we had has gone. kill -0 sends no signal at all: it just asks
  # "does this process still exist?"
  if [[ -z $PID ]] || ! kill -0 $PID 2>/dev/null; then
    PID=$(pgrep -f "$FFNAME -stats_period 1")
  fi
  
  if [[ -z $PID ]]; then
    rm -f "$CONFDIR/txt/nowplaying.txt" 2>/dev/null    # Thereby triggering termination of the loop
  fi

done
stty "$ORIG_STTY" 2>/dev/null