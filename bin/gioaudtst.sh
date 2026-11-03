#!/usr/bin/env bash
####################################################################
#
# gioaudtst: test for audio playback correct configuration
#
####################################################################
dialog --stdout --backtitle "Giocoso Audio Test" --msgbox "Your current Audio Device is configured to be $DEVICE. \n\nIf that's correct, you should hear a brief bit of music playing when you press OK." 8 80

clear
MESSAGE="Now playing an audio sample..."
if [[ $OSFAMILY == *MACOS* ]]; then
  $FFMPEG -nostdin -hide_banner -i "$CONFDIR/art/testaudio.flac" -max_muxing_queue_size 900000 -f audiotoolbox -  > "$CONFDIR/txt/ffmpeg-error.log" 2>&1 & spinner $! # Do this if macOS
elif [[ $(uname -a) == *microsoft* ]]; then
  $FFMPEG -nostdin -hide_banner -i "$CONFDIR/art/testaudio.flac" -max_muxing_queue_size 900000 -f pulse -  > "$CONFDIR/txt/ffmpeg-error.log" 2>&1 & spinner $!  # Do this if running in WSL2/Windows
else
  if [[ $FORCE_PULSE -eq 1 ]]; then
    $FFMPEG -nostdin -hide_banner -i "$CONFDIR/art/testaudio.flac" -max_muxing_queue_size 900000 -f pulse -  > "$CONFDIR/txt/ffmpeg-error.log" 2>&1 & spinner $! # Do this if wanting to do network client/server
  else
    $FFMPEG -nostdin -hide_banner -i "$CONFDIR/art/testaudio.flac" -max_muxing_queue_size 900000 -f alsa "$AUDIODEVICE" > "$CONFDIR/txt/ffmpeg-error.log" 2>&1 & spinner $! # Do this if on regular Linux
  fi
fi

dialog --stdout --backtitle "Giocoso Audio Test" --yesno "Did you hear the audio clip play correctly?" 8 80  # (0 = Yes, 1 = No).
exitStatus=$?

if [[ $exitStatus -eq 1 ]]; then
  dialog --stdout --backtitle "Giocoso Audio Test" --msgbox "Since you heard nothing just now, you should press OK to show the error log. Review it for any errors and consider re-configuring your Giocoso persistent configuration file to set a new audio device. \n\nThe command 'aplay -l' can help you see what sound devices exist on your system." 12 80
  tput setaf $MAINTEXT; less "$CONFDIR/txt/ffmpeg-error.log"
fi
