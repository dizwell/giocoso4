#!/usr/bin/env bash
####################################################################
#
# gioplaylist: routine for displaying a form listing all .play
# files found in the $CONFDIR/play folder, allowing selection of
# one for subsequent play
#
####################################################################
old_IFS=$IFS

# List all play files in the play sub-folder and present them for selection
IFS=$'\n'
PLAYLIST=()
for i in "$CONFDIR/play/"*.play; do
  [[ -e $i ]] || continue	
  PLAYNM="$(gbasename $i)"; PLAYNM="${PLAYNM%.*}"
  PLAYLIST+=("$PLAYNM" "$PLAYNM" off)
done
if ((${#PLAYLIST[@]} == 0)); then
  dialog --backtitle "Giocoso Music Selection by Playlist" --title " No Playlists Available! " --msgbox "\nNo playlists were found in the /play folder of the Giocoso installation. Press OK to return to the main menu." 8 80
  return 1
fi


playlist_name=$(dialog --no-tags --backtitle "Giocoso Music Selection by Playlist" --radiolist "Select a playlist to play" 12 80 0 "${PLAYLIST[@]}" 3>&1 1>&2 2>&3 3>&- )
exitStatus=$?

if [[ $exitStatus -ne 0 || -z $playlist_name ]]; then
  unset playlist_name
else
  playlist_name="$CONFDIR/play/$playlist_name".play
fi
IFS=${old_IFS}
