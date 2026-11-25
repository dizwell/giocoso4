#!/usr/bin/env bash
####################################################################
# giomenudraw: Clear screen drawing routine
####################################################################
# Determine if we're running the Beta or the Stable release and display accordingly.
INSTALLDIR="$(command -v giocoso4.sh)"

if [[ ! $($SEDPROG -n '9p' "$INSTALLDIR" 2>/dev/null | $GREPPROG -o '?') ]]; then 
  PROGBETA="no"; PROGVERSION="4.00"
else 
  PROGBETA="yes"
  # A beta install adds the date (UTC, as YYMMDD) of the GitHub commit it holds, so two beta installs can be told apart: a git clone
  # (as on a development machine, updated by git pull) asks git; an ordinary install uses the commit its installer recorded
  if [[ -d $CONFDIR/.git ]] && command -v git >/dev/null 2>&1; then
    BETADATE=$(TZ=UTC0 git -C "$CONFDIR" log -1 --format=%cd --date=format-local:%y%m%d 2>/dev/null)
  else
    BETADATE=$($GREPPROG -m1 '^INSTDATE=' "$CONFDIR/txt/installedversion.txt" 2>/dev/null | $SEDPROG 's/^INSTDATE="..\(..\)-\(..\)-\(..\).*/\1\2\3/')
  fi
  if [[ $BETADATE =~ ^[0-9]{6}$ ]]; then PROGVERSION="4.00-$BETADATE"; else PROGVERSION="4.00-beta"; fi
fi

if [[ $PROGBETA == "yes" ]]; then 
  LOGO_PATH="$CONFDIR/art/giocosoicosmallbeta.png"
else
  LOGO_PATH="$CONFDIR/art/giocosoicosmall.png"
fi

if [[ $CONNECTEDTO == "$THISHOST" ]]; then 
  DISPLAYHOST="$(tput setaf $INFOTEXT)$THISHOST $(tput setaf $LOGO)as own client"
else
  DISPLAYHOST="$(tput setaf $INFOTEXT)$CONNECTEDTO $(tput setaf $LOGO)as client"
fi

function sixel_logo {
wordlogo
logowidth="${LOGOSIZE%%x*}"
tput cup 14 60; tput setaf $SPINNER; echo -en "♬♪ "; tput setaf $INFOTEXT; echo -en "The Classical Music Player"; tput setaf $SPINNER; echo -en " ♬♪"
tput cup 16 $LOGO_POSITION; "$SIXEL" -w $logowidth "$LOGO_PATH" 2>/dev/null
}

function wordlogo {
tput setaf $LOGO
tput cup 8 57;  echo "  ____  _"
tput cup 9 57;  echo " / ___|(_) ___  ___  ___   ___   ___"
tput cup 10 57; echo "| |  _ | |/ _ \/ __|/ _ \ / __| / _ \ "
tput cup 11 57; echo "| |_| || | (_)| (__| (_) |\__ \| (4̲) |"
tput cup 12 57; echo " \____||_|\___/\___|\___/ |___/ \___/"
}

function short {
clear; tput cup 0 0;
tput setaf $DRAWLINES
echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
tput cup 1 4; tput setaf $SPINNER; echo -en "♬♪ "; tput setaf $LOGO; echo -en "Giocoso: The Classical Music Player"; tput setaf $SPINNER; echo -en " ♬♪"
tput cup 2 4; tput setaf $LOGO; echo "Copyright © H. Rogers $COPYRIGHT, v$PROGVERSION"
}

function playing {
clear; tput cup 0 0;
tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
├─────────────────────────────────────────────────┬─────────────────────────────────────────────────┤
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
├─────────────────────────────────────────────────┴─────────────────────────────────────────────────┤
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
tput cup 1 4; tput setaf $SPINNER; echo -en "♬♪ "; tput setaf $LOGO; echo -en "Giocoso: The Classical Music Player"; tput setaf $SPINNER; echo -en " ♬♪"
tput cup 2 4; tput setaf $LOGO; echo "Copyright © H. Rogers $COPYRIGHT, v$PROGVERSION"
tput cup 3 4; tput setaf $LOGO; echo -en "Connected to $DISPLAYHOST"
tput setaf $LOGO
sixel_logo  
}

function minig {
clear; tput cup 0 0;
tput setaf $DRAWLINES; echo -e "┌─────────────────────────────────────────────────┐
│                                                 │
│                                                 │
├─────────────────────────────────────────────────┤
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
├─────────────────────────────────────────────────┤
│                                                 │
└─────────────────────────────────────────────────┘"
tput cup  1 4; tput setaf $SPINNER; echo -en "♬♪ "; tput setaf $LOGO; echo -en "Giocoso: The Classical Music Player"; tput setaf $SPINNER; echo -en " ♬♪"
tput cup  2 4; tput setaf $LOGO; echo "Minimal Player - Version $PROGVERSION"
tput cup 23 4; tput setaf $LOGO; echo -en "PulseAudio Server: "; tput setaf $INFOTEXT; echo -en "$PULSESERVER"
}

function default {
clear; tput cup 0 0;
tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
├───────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                   │
├─────────────────────────────────────────────────┬─────────────────────────────────────────────────┤
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
├─────────────────────────────────────────────────┴─────────────────────────────────────────────────┤
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
tput cup  1 4; tput setaf $SPINNER; echo -en "♬♪ "; tput setaf $LOGO; echo -en "Giocoso: The Classical Music Player"; tput setaf $SPINNER; echo -en " ♬♪"
tput cup  2 4; tput setaf $LOGO; echo "Copyright © H. Rogers $COPYRIGHT, v$PROGVERSION"
tput cup 3 4; tput setaf $LOGO; echo -en "Connected to $DISPLAYHOST"

tput setaf $LOGO
sixel_logo
}

function main {
DISPLAYDBS="${SOURCEDB^}"; DISPLAYDBS=${DISPLAYDBS:0:29}
LOGO_POSITION=$((70 + $LOGOPOS ))      # Centred in the right-hand panel at the default size (as Semplice and Niente)
if [[ $1 == short ]]; then
  short
elif  [[ $1 == playing ]]; then
  playing
elif [[ $1 == minig ]]; then
  minig
else
  default 
fi
}

main "$@"