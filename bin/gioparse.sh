#!/usr/bin/env bash
####################################################################
#
# gioparse: routine for parsing the persistent configuration
# file and deriving sensible values from whatever is supplied there.
#
####################################################################

if [[ -z $EDITOR ]]; then EDITOR=nano; fi;
if [[ -z $HOTKEY ]]; then HOTKEY=11; fi
if [[ -z $DRAWLINES ]]; then DRAWLINES=2; fi
if [[ -z $MAINTEXT ]]; then MAINTEXT=15; fi
if [[ -z $LOGO ]]; then LOGO=6; fi
if [[ -z $INFOTEXT ]]; then INFOTEXT=11; fi
if [[ -z $SPINNER ]]; then SPINNER=12; fi
if [[ -z $ALERT ]]; then ALERT=1; fi
if [[ -z $VSPEED ]]; then VSPEED=160; fi

if [[ -f "$CONFDIR/txt/giocoso.conf" ]]; then
  source "$CONFDIR/txt/giocoso.conf"

  if ! [[ -z $SELECTIONS ]]; then 							# Selections, if set, must be a number. If not numeric, or out of bounds, the default is 10.
     if ! [[ $SELECTIONS =~ ^[0-9]+$ ]] ; then
       SELECTIONS=10
	 fi
  else
    SELECTIONS=10
  fi

  if ! [[ -z $ACCENTS ]]; then 								# Accents, if set, should be set to 'Yes' by default unless explicitly set to no.
    if [[ ${ACCENTS^^} == "NO" ]]; then
	  UTFCHARS=""
	else
	  UTFCHARS="--no-utf8-convert"
	fi
  else
    UTFCHARS="--no-utf8-convert"
  fi

  if ! [[ -z $DEVICE ]]; then 								# Device can be set to anything (if it's wrong, no audio will be heard!), but if it's not set then 'default' is applied as a specific setting.
    AUDIODEVICE="$DEVICE"
  else
    AUDIODEVICE="default"
  fi

  if [[ -z $FORCE_PULSE ]]; then								# Force Pulse defaults to no, unless explicitly set to yes.
    FORCE_PULSE=0
  elif  [[ ${FORCE_PULSE^^} == "YES" ]]; then
    FORCE_PULSE=1
  else
    FORCE_PULSE=0
  fi

  if ! [[ -z $TIMEBAR ]]; then 								# Timebar, if set, must be a positive number. If not numeric, or out of bounds, the default timebar is 24 hours.
    if ! [[ $TIMEBAR =~ ^[0-9]+$ ]]; then
      TIMEBAR=24
    elif [[ $TIMEBAR -lt 0 ]]; then
      TIMEBAR=24
	else
	  TIMEBAR=$TIMEBAR
    fi
  else
    TIMEBAR=24
  fi
  TIMEBAR=$(( TIMEBAR * -1))  								# Time logic in SQL means the parameter value has to be turned into a negative number to work properly. "18" becomes "-18", etc

  # Artsize is supplied as a single number (defaulting to 340 if blank or non-numeric), but must become a "AxA" textual parameter
  if ! [[ -z $ARTSIZE ]]; then
    ARTSIZE="${ARTSIZE}x${ARTSIZE}"	  
  else
	  ARTSIZE="340x340"
  fi
  
  # Logosize is the same thing: defaults to 110x110, but a single number supplied must become a BxB textual parameter
  if ! [[ -z $LOGOSIZE ]]; then
    LOGOSIZE="${LOGOSIZE}x${LOGOSIZE}"	  
  else
	  LOGOSIZE="110x110"
  fi  
  
  if [[ -z $DURATIONS ]]; then 							# Durations for reporting in either hours or minutes. If not set, or not explicitly set to 'hours', minutes is the default.
    DURATIONS="MINUTES"
  elif [[ ${DURATIONS^^} != "HOURS" ]]; then
    DURATIONS="MINUTES"
  else
    DURATIONS="HOURS"
  fi

  # The Countdown parameter governs delays between successive plays. It needs to be numeric. Defaults to 120
  if ! [[ -z $COUNTDOWN ]]; then
    if ! [[ $COUNTDOWN =~ ^[0-9]+$ ]] ; then
      COUNTDOWN=120
    elif [[ $COUNTDOWN -lt 0 ]]; then
      COUNTDOWN=120
    else
	  COUNTDOWN=$COUNTDOWN
    fi
  else
    COUNTDOWN=120
  fi
  
  # The Vspeed parameter controls the speed or rate with which the artifical voice makes announcements. Needs to be numeric. Defaults to 160
  if ! [[ -z $VSPEED ]]; then
	if ! [[ $VSPEED =~ ^[0-9]+$ ]]; then
	  VSPEED=160
	elif [[ $VSPEED -lt 0 ]]; then
	  VSPEED=160   
	else
	  VSPEED=$VSPEED
    fi
  else
	VSPEED=160
  fi

  # The MySQL IP parameter, if set, needs to be a proper IP address
  if ! [[ -z $MYSQLIP ]]; then
    if ! [[ $MYSQLIP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
      MYSQLIP="127.0.0.1"
    else
	  MYSQLIP=$MYSQLIP
    fi
  else
    MYSQLIP="127.0.0.1"
  fi
  
  # The PULSESERVER IP parameter, if set, needs to be a proper IP address
  if ! [[ -z $PULSESERVER ]]; then
    if ! [[ $PULSESERVER =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
      PULSESERVER=""
    else
	  PULSESERVER=$PULSESERVER
    fi
  else
    PULSESERVER=""
  fi

  # The MySQL Port parameter, if set, needs to be numeric and defaults to 3306
  if ! [[ -z $MYSQLPRT ]]; then
    if ! [[ $MYSQLPRT =~ ^[0-9]+$ ]] ; then
      MYSQLPRT=3306
    elif [[ $MYSQLPRT -lt 0 ]]; then
      MYSQLPRT=3306
    else
	  MYSQLPRT=$MYSQLPRT
    fi
  else
    MYSQLPRT=3306
  fi

  # The File Prefix parameter, if set, should NOT end in a final slash. Remove it if it does.
  if ! [[ -z $FILEPREFIX ]]; then
    if [[ ${FILEPREFIX: -1} == "/" ]]; then
      FILEPREFIX="${FILEPREFIX%?}"
    else
	  FILEPREFIX="$FILEPREFIX"
    fi
  fi

  # Now to determine how to connect to the Giocoso database. It should be Mariadb, but some distros
  # may still use the 'mysql' alias.
  MARIAPRESENT=$(mysql --version 2> /dev/null | grep MariaDB | wc -l)
  if [[ $MARIAPRESENT -eq 1 ]]; then
    if mariadb --help 2>/dev/null | grep -q -- '--ssl-mode'; then
      SSL_OPTS="--ssl-mode=DISABLED"
    elif mariadb --help 2>/dev/null | grep -q -- '--skip-ssl'; then
      SSL_OPTS="--skip-ssl"
    else
      SSL_OPTS=""
    fi
  fi

  if [[ $MARIAPRESENT -eq 1 ]]; then
    PROCONN=()
    if [[ $(uname -a) == *"Darwin"* ]]; then 
      PROCONN+=(mariadb --default-character-set=utf8mb4 --connect-timeout=1 -u giocoso4 -h "$MYSQLIP" -pgiocoso4 -P "$MYSQLPRT" -D giocoso4)
    else
      PROCONN+=(/usr/bin/mariadb --default-character-set=utf8mb4 --connect-timeout=1 -u giocoso4 -h "$MYSQLIP" -pgiocoso4 -P "$MYSQLPRT" -D giocoso4)
    fi
    if [[ -n $SSL_OPTS ]]; then
      PROCONN+=($SSL_OPTS)
    fi
	CONNECTEDTO=$("${PROCONN[@]}" -N -B -e "SELECT @@hostname"); CONNECTEDTO="${CONNECTEDTO%%.*}"
	THISHOST=$(hostname); THISHOST="${THISHOST%%.*}"
  else
    PROCONN=()
    if [[ $(uname -a) == *"Darwin"* ]]; then
      PROCONN+=(mysql --default-character-set=utf8mb4 --connect-timeout=1 -u giocoso4 -h "$MYSQLIP" -pgiocoso4 -P "$MYSQLPRT" -D giocoso4)
    else
      PROCONN+=(/usr/bin/mysql --default-character-set=utf8mb4 --connect-timeout=1 -u giocoso4 -h "$MYSQLIP" -pgiocoso4 -P "$MYSQLPRT" -D giocoso4)
    fi
	CONNECTEDTO=$("${PROCONN[@]}" -N -B -e "SELECT @@hostname"); CONNECTEDTO="${CONNECTEDTO%%.*}"
	THISHOST=$(hostname); THISHOST="${THISHOST%%.*}"
  fi
  
  if [[ $(uname -s) == Darwin ]]; then
      if [[ -x /opt/local/lib/mariadb-11.4/bin/mariadb-dump ]]; then
          MARIADBDUMP=/opt/local/lib/mariadb-11.4/bin/mariadb-dump
      elif [[ -x /opt/homebrew/bin/mariadb-dump ]]; then
          MARIADBDUMP=/opt/homebrew/bin/mariadb-dump
      elif [[ -x /usr/local/bin/mariadb-dump ]]; then
          MARIADBDUMP=/usr/local/bin/mariadb-dump
      fi
  else
      MARIADBDUMP=$(command -v mariadb-dump)
  fi
  
  if ! [[ -z $ANNOUNCEPLAY ]]; then 								# Announcements, if set, should be set to 'No' by default unless explicitly set to yes.
    if [[ ${ANNOUNCEPLAY^^} == "YES" ]]; then
	  ANNOUNCEPLAY="YES"
	else
	  ANNOUNCEPLAY="NO"
	fi
  else
    ANNOUNCEPLAY="NO"
  fi
  
else
  # If no existing configuration file exists, create one using all-default values and then re-parse it.
  # Text values are double-quoted because the file gets sourced, and values may contain spaces.
  cat > "$CONFDIR/txt/giocoso.conf" <<CONFEOF
# New Giocoso Configuration File, created $(date),
# with all parameters set to their default values.
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
DEVICE="default"
DURATIONS="minutes"
BACKUP_DIR="$HOME"
MYSQLIP="127.0.0.1"
MYSQLPRT="3306"
FILEPREFIX=""
BROWSER=""
PULSESERVER=""
WEZTHEME="Banana Blueberry"
DIATHEME="standard"

# Parameters requiring numeric entries
# ====================================================================
SELECTIONS=10
TIMEBAR=24
ARTSIZE=340
COUNTDOWN=120
LOGOSIZE=110
LOGOPOS=0
WEZFNTSZ=12

# Parameters requiring yes/no entries
# ====================================================================
ACCENTS=yes
FORCE_PULSE=no
USERPG=yes
ANNOUNCEPLAY=no
VSPEED=160
CONFEOF
  chmod 775 "$CONFDIR/txt/giocoso.conf"
  parse_config
fi