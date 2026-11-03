#!/usr/bin/env bash
####################################################################
#
# gioconfconstruct.sh: A function to construct a configuration file, 
# based on replies to prompts.
#
####################################################################
CONFIG_COMPLETE=0 CONFFILE="$CONFDIR/txt/giocoso.conf"

trap cancel_edit TERM      # Trap to quit nicely if the terminal is closed by clicking 'X' icon in window titlebar (works for xterm, not for all terminals)
trap cancel_edit SIGHUP    # Same thing, different signal
trap cancel_edit INT       # Trap to prevent Ctrl+C from working

function cancel_edit {
  trap exit_program TERM; trap exit_program SIGHUP; trap exit_program INT
  clear; gmenuoptions admin
  return
}

function conf_text {
# Print the value of key $1 from the config file, minus any surrounding double quotes
$GREPPROG -i -m1 "^$1=" "$CONFFILE" | $SEDPROG -e 's/^[^=]*=//' -e 's/^"//' -e 's/"$//'
}

function get_existing_values {
# Read parameters from an existing config file, if present
# ====================================================================
if [[ -f $CONFFILE ]]; then
  # Text Parameters (conf_text strips the surrounding double quotes, and copes with '=' inside a value)
  confdevice=$(conf_text DEVICE); if [[ -z $confdevice ]]; then confdevice='default'; fi
  confdurations=$(conf_text DURATIONS); if [[ -z $confdurations ]]; then confdurations=minutes; fi
  confbackupdir=$(conf_text BACKUP_DIR); if [[ -z $confbackupdir ]]; then confbackupdir="$HOME/Desktop"; fi
  confmysqlip=$(conf_text MYSQLIP); if [[ -z $confmysqlip ]]; then confmysqlip=127.0.0.1; fi
  confmysqlprt=$(conf_text MYSQLPRT); if [[ -z $confmysqlprt ]]; then confmysqlprt=3306; fi
  conffileprefix=$(conf_text FILEPREFIX)
  confbrowz=$(conf_text BROWSER)
  confpulse=$(conf_text PULSESERVER)
  confweztheme=$(conf_text WEZTHEME); if [[ -z $confweztheme ]]; then confweztheme="Banana Blueberry"; fi
  confdiatheme=$(conf_text DIATHEME); if [[ -z $confdiatheme ]]; then confdiatheme="standard"; fi
  
  # Numerics
  confselections=$(cat "$CONFFILE" | $GREPPROG -i SELECTIONS= | awk -F= '{print $2}'); if [[ -z $confselections || ! $confselections =~ ^[0-9]+$ ]]; then confselections=1; fi
  conftimebar=$(cat "$CONFFILE" | $GREPPROG -i TIMEBAR= | awk -F= '{print $2}'); if [[ -z $conftimebar || ! $conftimebar =~ ^[0-9]+$ ]]; then conftimebar=6; fi
  confartsize=$(cat "$CONFFILE" | $GREPPROG -i ARTSIZE= | awk -F= '{print $2}'); if [[ -z $confartsize || ! $confartsize =~ ^[0-9]+$ ]]; then confartsize=341; fi
  confcount=$(cat "$CONFFILE" | $GREPPROG -i COUNTDOWN= | awk -F= '{print $2}'); if [[ -z $confcount || ! $confcount =~ ^[0-9]+$ ]]; then confcount=120; fi
  conflogosize=$(cat "$CONFFILE" | $GREPPROG -i LOGOSIZE= | awk -F= '{print $2}'); if [[ -z $conflogosize || ! $conflogosize =~ ^[0-9]+$ ]]; then conflogosize=120; fi
  conflogopos=$(cat "$CONFFILE" | $GREPPROG -i LOGOPOS= | awk -F= '{print $2}'); if [[ -z $conflogopos || ! $conflogopos =~ ^-?[0-9]+$ ]]; then conflogopos=0; fi
  confwezfntsz=$(cat "$CONFFILE" | $GREPPROG -i WEZFNTSZ= | awk -F= '{print $2}'); if [[ -z $confwezfntsz || ! $confwezfntsz =~ ^[0-9]+$ ]]; then confwezfntsz=12; fi
  
  # YesNos
  confaccents=$(cat "$CONFFILE" | $GREPPROG -i ACCENTS= | awk -F= '{print $2}'); if [[ -z $confaccents ]]; then confaccents=yes; fi
  confpulseaudio=$(cat "$CONFFILE" | $GREPPROG -i FORCE_PULSE= | awk -F= '{print $2}'); if [[ -z $confpulseaudio ]]; then confpulseaudio=no; fi
  confrpg=$(cat "$CONFFILE" | $GREPPROG -i USERPG= | awk -F= '{print $2}'); if [[ -z $confrpg ]]; then confrpg=yes; fi
  confvoice=$(cat "$CONFFILE" | $GREPPROG -i ANNOUNCEPLAY= | awk -F= '{print $2}'); if [[ -z $confvoice ]]; then confvoice=no; fi
  confvspeed=$(cat "$CONFFILE" | $GREPPROG -i VSPEED= | awk -F= '{print $2}'); if [[ -z $confvspeed ]]; then confvspeed=160; fi
fi
}

function textual_parameters {
dialog --backtitle "Giocoso Configuration File Editor" --title " Program Configuration " --extra-button --extra-label "Defaults" --form "Parameters requiring text entries:" 18 90 11 \
"Audio device to use as default output " 1 1  "$confdevice"   1 50 35 0 \
"Report durations in Hours or Minutes " 2 1  "$confdurations" 2 50 35 0 \
"Folder where to write database backups " 3 1  "$confbackupdir"     3 50 35 0 \
"Giocoso Server IP Address" 4 1 "$confmysqlip" 4 50 35 0 \
"Giocoso Server Port" 5 1 "$confmysqlprt" 5 50 35 0 \
"Local music folder prefix" 6 1 "$conffileprefix" 6 50 35 0 \
"Preferred browser" 7 1 "$confbrowz" 7 50 35 0 \
"PulseAudio Server IP Address" 8 1 "$confpulse" 8 50 35 0 \
"Giocoso colour theme name" 9 1 "$confweztheme" 9 50 35 0 \
"Dialog colour theme name" 10 1 "$confdiatheme" 10 50 35 0 \
2>"$CONFDIR/tmp/txtparams"
exitStatus=$?
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then       	# They've pressed Cancel or ESC
  cancel_edit
fi

if [[ $exitStatus -eq 3 ]]; then  								# They've pressed the 'Reset to defaults' button. So set defaults and re-display
  CONFDEVICE="default"				; confdevice="$CONFDEVICE"
  CONFDURATIONS="minutes"			; confdurations="$CONFDURATIONS"
  CONFBACKUPDIR="$HOME"				; confbackupdir="$CONFBACKUPDIR"
  CONFMYSQLIP="127.0.0.1"			; confmysqlip="$CONFMYSQLIP"
  CONFMYSQLPRT="3306"				; confmysqlprt="$CONFMYSQLPRT"
  CONFFILEPREFIX=""					; conffileprefix="$CONFFILEPREFIX"
  CONFBROWZ="firefox"				; confbrowz="$CONFBROWZ"
  CONFPULSE=""						; confpulse="$CONFPULSE"
  CONFWEZTHEME="Banana Blueberry"	; confweztheme="$CONFWEZTHEME"
  CONFDIATHEME="standard"			; confdiatheme="$CONFDIATHEME"
  textual_parameters
else
  readarray -t txtparams < "$CONFDIR/tmp/txtparams" 2>/dev/null
  CONFDEVICE="${txtparams[0]}"; if [[ -z $CONFDEVICE ]]; then CONFDEVICE=default; fi
  CONFDURATIONS="${txtparams[1]}"; if [[ -z $CONFDURATIONS ]]; then CONFDURATIONS=minutes; fi
  CONFBACKUPDIR="${txtparams[2]}"
  CONFMYSQLIP="${txtparams[3]}"
  CONFMYSQLPRT="${txtparams[4]}"; if [[ -z $CONFMYSQLPRT ]]; then CONFMYSQLPRT=3306; fi
  CONFFILEPREFIX="${txtparams[5]}"
  CONFBROWZ="${txtparams[6]}"
  CONFPULSE="${txtparams[7]}"
  CONFWEZTHEME="${txtparams[8]}"
  CONFDIATHEME="${txtparams[9]}"
fi

# Make sure the backup folder is set to something, and the something actually exists and it's something we can write to!
if [[ -z $CONFBACKUPDIR ]]; then CONFBACKUPDIR="/tmp"; fi;
if [[ ! -d $CONFBACKUPDIR ]]; then CONFBACKUPDIR="/tmp"; fi
if [[ ! -w $CONFBACKUPDIR ]]; then CONFBACKUPDIR="/tmp"; fi
	
# Make sure CONFDIATHEME is one of giocosodialog, transparent, green or yellow. If not, it's giocosodialog
if [[ ${CONFDIATHEME,,} =~ ^(standard|red|green|yellow|magenta)$ ]]; then
  CONFDIATHEME=${CONFDIATHEME,,}	
else
  CONFDIATHEME=standard
fi
unset exitStatus
}

function numeric_parameters {
dialog --backtitle "Giocoso Configuration File Editor" --title " Program Configuration " --extra-button --extra-label "Defaults" --form "Parameters requiring numeric entries:" 18 90 12 \
"Number of plays per cycle " 1 1  "$confselections" 1 65 15 0 \
"Hours before composer eligible for next play" 2 1  "$conftimebar"     2 65 15 0 \
"Seconds to wait before playback starts" 3 1  "$confcount"     3 65 15 0 \
"Size of album art when displayed (in pixels)" 4 1  "$confartsize"     4 65 15 0 \
"Size of the Program Logo" 5 1  "$conflogosize"     5 65 15 0 \
"Program Logo position (- or +)" 6 1  "$conflogopos"     6 65 15 0 \
"Giocoso font size (in points)" 7 1 "$confwezfntsz" 7 65 15 0 \
2>"$CONFDIR/tmp/numparams"
exitStatus=$?
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then        # They've pressed Cancel or ESC
  cancel_edit
fi

if [[ $exitStatus -eq 3 ]]; then  								# They've pressed the 'Reset to defaults' button. So set defaults and re-display
  CONFSELECTIONS="10"  	;	confselections="$CONFSELECTIONS"
  CONFTIMEBAR="24"     	;	conftimebar="$CONFTIMEBAR"
  CONFCOUNT="120"      	; 	confcount="$CONFCOUNT"
  CONFARTSIZE="340"    	; 	confartsize="$CONFARTSIZE"
  CONFLOGOSIZE="110"   	; 	conflogosize="$CONFLOGOSIZE"
  CONFLOGOPOS="0"     	; 	conflogopos="$CONFLOGOPOS"
  CONFWEZFNTSZ="12"    	; 	confwezfntsz="$CONFWEZFNTSZ"
  numeric_parameters
else
  readarray -t numparams < "$CONFDIR/tmp/numparams" 2>/dev/null

  # Process the numeric parameters: They mostly need to be positive integers, with defaults applied where they fail that test
  # The regex used will reject both null and negatives. Logopos uses a slightly different regex that permits negatives
  # ====================================================================
  CONFSELECTIONS="${numparams[0]}"  ; if [[ ! $CONFSELECTIONS =~ ^[0-9]+$ ]]; then CONFSELECTIONS=1; fi
  CONFTIMEBAR="${numparams[1]}"     ; if [[ ! $CONFTIMEBAR =~ ^[0-9]+$ ]]; then CONFTIMEBAR=6; fi
  CONFCOUNT="${numparams[2]}"       ; if [[ ! $CONFCOUNT =~ ^[0-9]+$ ]]; then CONFCOUNT=120; fi
  CONFARTSIZE="${numparams[3]}"     ; if [[ ! $CONFARTSIZE =~ ^[0-9]+$ ]]; then CONFARTSIZE=340; fi
  CONFLOGOSIZE="${numparams[4]}"    ; if [[ ! $CONFLOGOSIZE =~ ^[0-9]+$ ]]; then CONFLOGOSIZE=110; fi
  CONFLOGOPOS="${numparams[5]}"     ; if [[ ! $CONFLOGOPOS =~ ^-?[0-9]+$ ]]; then CONFLOGOPOS=0; fi
  CONFWEZFNTSZ="${numparams[6]}"    ; if [[ ! $CONFWEZFNTSZ =~ ^[0-9]+$ ]]; then CONFWEZFNTSZ=12; elif [[ $CONFWEZFNTSZ -gt 32 ]]; then CONFWEZFNTSZ=12; elif [[ $CONFWEZFNTSZ -lt 8 ]]; then CONFWEZFNTSZ=12; fi
fi
unset exitStatus
}
  
function yesno_parameters {
dialog --backtitle "Giocoso Configuration File Editor" --title " Program Configuration " --extra-button --extra-label "Defaults" --form "Parameters mostly requiring yes/no answers:" 17 90 10 \
"Prevent conversion of accented to non-accented characters " 1 1  "$confaccents" 1 70 5 0 \
"Force the use of PulseAudio by default" 2 1  "$confpulseaudio"     2 70 5 0 \
"Use ReplayGain if appropriate tags present" 3 1 "$confrpg"  3 70 5 0 \
"Announce plays before they begin" 4 1 "$confvoice"  4 70 5 0 \
"Announcement speed" 5 1 "$confvspeed" 5 70 5 0 \
2>"$CONFDIR/tmp/yornparams"
exitStatus=$?
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then        # They've pressed Cancel or ESC
  cancel_edit
fi

if [[ $exitStatus -eq 3 ]]; then  								# They've pressed the 'Reset to defaults' button. So set defaults and re-display
  CONFACCENTS="yes"		;	confaccents="$CONFACCENTS"
  CONFPULSEAUDIO="no"	;	confpulseaudio="$CONFPULSEAUDIO"
  CONFRPG="yes"			;	confrpg="$CONFRPG"
  CONFVOICE="no"		;	confvoice="$CONFVOICE"
  yesno_parameters
else
  readarray -t yornparams < "$CONFDIR/tmp/yornparams" 2>/dev/null
  CONFACCENTS="${yornparams[0]}"; 		if [[ -z $CONFACCENTS ]]; then CONFACCENTS="yes"; fi; 		if [[ ${CONFACCENTS^^} == *N* ]]; then CONFACCENTS="no"; else CONFACCENTS="yes"; fi
  CONFPULSEAUDIO="${yornparams[1]}"; 	if [[ -z $CONFPULSEAUDIO ]]; then CONFPULSEAUDIO="no"; fi; 	if [[ ${CONFPULSEAUDIO^^} == *Y* ]]; then CONFPULSEAUDIO="yes"; else CONFPULSEAUDIO="no"; fi
  CONFRPG="${yornparams[2]}"; 			if [[ -z $CONFRPG ]]; then CONFRPG="yes"; fi; 				if [[ ${CONFRPG^^} == *N* ]]; then CONFRPG="no"; else CONFRPG="yes";fi
  CONFVOICE="${yornparams[3]}"; 		if [[ -z $CONFVOICE ]]; then CONFVOICE="no"; fi; 				if [[ ${CONFVOICE^^} == *Y* ]]; then CONFVOICE="yes"; else CONFVOICE="no";fi
  CONFVSPEED="${yornparams[4]}"; 		if [[ -z $CONFVSPEED ]]; then CONFVSPEED="160"; fi
fi
CONFIG_COMPLETE=1
unset exitStatus
}

function create_conf {
local v bad='[\"$`\\]'
# Text values are written inside double quotes and the file is later sourced, so strip anything
# that would break out of (or be expanded inside) those quotes: " $ ` and backslash
# ====================================================================
for v in CONFDEVICE CONFDURATIONS CONFBACKUPDIR CONFMYSQLIP CONFMYSQLPRT CONFFILEPREFIX CONFBROWZ CONFPULSE CONFWEZTHEME CONFDIATHEME; do
  printf -v "$v" '%s' "${!v//$bad/}"
done

# First backup the existing configuration file
# ====================================================================
if [[ -f $CONFDIR/txt/giocoso.conf ]]; then
  cp "$CONFDIR/txt/giocoso.conf" "$CONFDIR/txt/giocoso.conf-$(date +%F-%T).bkp"
fi

# Now write all the new parameter values to a new configuration file. The heredoc
# keeps the double quotes literal, so no escaping is needed (and WEZTHEME no longer
# needs special treatment).
# ====================================================================
cat > "$CONFDIR/txt/giocoso.conf" <<CONFEOF
# New Giocoso Configuration File, created $(date)
# ====================================================================

# Colour Constants (alter at your peril!)
# ====================================================================
HOTKEY=11
DRAWLINES=2
MAINTEXT=15
LOGO=6
INFOTEXT=11
SPINNER=12
ALERT=1

# Parameters requiring text entries (double-quoted, since values may contain spaces)
# ====================================================================
DEVICE="$CONFDEVICE"
DURATIONS="$CONFDURATIONS"
BACKUP_DIR="$CONFBACKUPDIR"
MYSQLIP="$CONFMYSQLIP"
MYSQLPRT="$CONFMYSQLPRT"
FILEPREFIX="$CONFFILEPREFIX"
BROWSER="$CONFBROWZ"
PULSESERVER="$CONFPULSE"
WEZTHEME="$CONFWEZTHEME"
DIATHEME="$CONFDIATHEME"

# Parameters requiring numeric entries
# ====================================================================
SELECTIONS=$CONFSELECTIONS
TIMEBAR=$CONFTIMEBAR
COUNTDOWN=$CONFCOUNT
ARTSIZE=$CONFARTSIZE
LOGOSIZE=$CONFLOGOSIZE
LOGOPOS=$CONFLOGOPOS
WEZFNTSZ=$CONFWEZFNTSZ

# Parameters requiring yes/no entries
# ====================================================================
ACCENTS=$CONFACCENTS
FORCE_PULSE=$CONFPULSEAUDIO
USERPG=$CONFRPG
ANNOUNCEPLAY=$CONFVOICE
VSPEED=$CONFVSPEED
CONFEOF

# Change the WezTerm theme to match what has been configured
# ====================================================================	
if [[ -f $HOME/.giocoso.lua ]]; then
  $SEDPROG -i "s/^config\.color_scheme = '.*'$/config.color_scheme = '$CONFWEZTHEME'/" "$HOME/.giocoso.lua" 2>/dev/null
  $SEDPROG -i "s/^config\.font_size = .*$/config.font_size = $CONFWEZFNTSZ/" "$HOME/.giocoso.lua" 2>/dev/null
fi

# Regenerate album art based on new logo size parameter
# ====================================================================
$MAGICK "$CONFDIR/art/giocosoicobeta.png" -resize "$CONFLOGOSIZE" "$CONFDIR/art/giocosoicosmallbeta.png" 2>/dev/null
$MAGICK "$CONFDIR/art/giocosoico.png" -resize "$CONFLOGOSIZE" "$CONFDIR/art/giocosoicosmall.png" 2>/dev/null  
}

# ====================================================================
# Executable code starts here
# ====================================================================
get_existing_values
textual_parameters
numeric_parameters
yesno_parameters

# Only create the new file if the entire set of parameters were saved
# ====================================================================
if [[ $CONFIG_COMPLETE -eq 1 ]]; then
  create_conf
fi

# Cleanup
# ====================================================================
rm -f "$CONFDIR/tmp/txtparams" 2>/dev/null
rm -f "$CONFDIR/tmp/numparams" 2>/dev/null
rm -f "$CONFDIR/tmp/yornparams" 2>/dev/null

# And now re-parse
source "$CONFDIR/bin/gioparse.sh"

# Re-instate global trap as we exit
trap exit_program TERM; trap exit_program SIGHUP; trap exit_program INT