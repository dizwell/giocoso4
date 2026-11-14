#!/usr/bin/env bash
####################################################################
#
# giocontrol: routine for controlling a playing session
# (i.e., handling skips, terminates, repeats etc). 
#
####################################################################
function get_rechash {
local FLACFILE ALBUM COMPOSER                       # Scratch values only: don't leak into (or overwrite) the caller's variables
RECHASHVALUE=""                                     # The one deliberate output: callers read this afterwards
FLACFILE=$(find "$PWD" -maxdepth 1 -name "*.flac" | sort | head -n 1)
[[ -n $FLACFILE ]] || return 1
ALBUM=$($METAFLAC $UTFCHARS --show-tag=Album "$FLACFILE" | $SEDPROG 's/.*=//g' 2>/dev/null)
COMPOSER=$($METAFLAC $UTFCHARS --show-tag=Artist "$FLACFILE" | $SEDPROG 's/.*=//g' 2>/dev/null)
RECHASHVALUE=$(echo -n "$COMPOSER$ALBUM" | $MD5PROG | gawk '{print $1}')
}

function handle_autostop {
if [[ ! -f $CONFDIR/txt/autostop.txt ]]; then
  if [[ $(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l) -gt 0 ]]; then
    touch "$CONFDIR/txt/autostop.txt"
  fi
else
  rm -f "$CONFDIR/txt/autostop.txt" 2>/dev/null
fi
}

function handle_skip {
if [[ ! -f $CONFDIR/txt/skip.txt ]]; then
  footer_line Skip; tput cup 25 4; echo -e "$FOOTER"; tput cup 3 77
  if [[ $(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l) -gt 0 ]]; then
    touch "$CONFDIR/txt/skip.txt"
    rm -f "$CONFDIR/txt/autostop.txt" 2>/dev/null
    rm -f "$CONFDIR/txt/repeat.txt" 2>/dev/null
    pkill -f "display -geometry" >/dev/null 2>&1
    FFPID=$(pgrep -f "$FFNAME -stats_period 1"); kill -9 $FFPID 2>/dev/null; wait $FFPID 2>/dev/null      # Only Giocoso's own playback, as everywhere else
    get_rechash && "${PROCONN[@]}" -e "delete from global_pauses where rechashvalue='$RECHASHVALUE'" >/dev/null 2>&1
  fi
fi
}

function handle_repeat {
if [[ ! -f $CONFDIR/txt/repeat.txt ]]; then
  if [[ $(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l) -gt 0 ]]; then
    touch "$CONFDIR/txt/repeat.txt"
  fi
else
  rm -f "$CONFDIR/txt/repeat.txt" 2>/dev/null
fi
}

function handle_pause {
# If a pause request is received, we need first to know if ffmpeg is actually playing anything!
# If it's not, then there's nothing to pause	
PID=$(pgrep -f "$FFNAME -stats_period 1")
if ! [[ -z $PID ]]; then
  # Once we know there's an active ffmpeg process, we need to know what music it's playing
  # and extract its tag data. If there's no FLAC file to read data from for some reason, we
  # return to the main menu early (so we don't end up inserting things into the database that
  # shouldn't be there)	
  get_rechash || return
		
  # We now need to know how far into the recording we've got. This is more complex than at first
  # appears: If Session A is 20 minutes into an hour-long recording and pauses, when Session B
  # resumes it and then pauses after 5 minutes, Session B will say it has played 5 minutes. But
  # we need to say that, cumulatively, 25 minutes of this recording has been played. Therefore, 
  # we need to fetch the previous play amount from global_pauses and add the *current* pause 
  # point onto it.
  
  # POSITION_IN_STREAM_IN_SECS is measured from where this play started. PLAY_OFFSET is
  # that starting point within the recording (0 for a normal play, the resume point for a
  # resumed one). Their sum is the true position, which is what we store. The next resume
  # then rewinds 5 seconds from this true position, every time.
  NEWPOS=${POSITION_IN_STREAM_IN_SECS%.*}

  if [[ -n $NEWPOS ]]; then
    ABSPOS=$(( ${PLAY_OFFSET:-0} + NEWPOS ))
    "${PROCONN[@]}" -e "insert into global_pauses (rechashvalue, current_play_location) values ('$RECHASHVALUE', $ABSPOS)
    on duplicate key update current_play_location = $ABSPOS;
    " >/dev/null 2>&1

    # Now kill the play off
    touch "$CONFDIR/txt/terminate.txt"
  fi
fi
}

function handle_terminate {
# Terminate needs to clear the decks: any prior autostop, pause, repeat or skip requests should be cleared out
footer_line Terminate; tput cup 25 4; echo -e "$FOOTER"; tput cup 3 77

get_rechash && "${PROCONN[@]}" -e "delete from global_pauses where rechashvalue='$RECHASHVALUE'" >/dev/null 2>&1
  
touch "$CONFDIR/txt/terminate.txt"
rm -f "$CONFDIR/txt/repeat.txt" 2>/dev/null
rm -f "$CONFDIR/txt/skip.txt" 2>/dev/null
rm -f "$CONFDIR/txt/autostop.txt" 2>/dev/null
}

if [[ $1 == autostop ]]; then handle_autostop; fi
if [[ $1 == skip ]]; then handle_skip; fi
if [[ $1 == repeat ]]; then handle_repeat; fi
if [[ $1 == pause ]]; then handle_pause; fi
if [[ $1 == terminate ]]; then handle_terminate; fi
if [[ $1 == exit ]]; then handle_terminate; fi
