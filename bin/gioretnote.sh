#!/usr/bin/env bash
####################################################################
#
# A function to display/edit existing notes for the playing recording
# and to permit the read-only display of any notes stored in the
# database.
#
####################################################################
NOCOMPOSER=0  NORECORDING=0

function fetch_note {
# Prints the stored note for $RECHASHVALUE exactly as written (--raw: no \n \t escaping), or nothing if there isn't one
[[ $RECHASHVALUE =~ ^[0-9a-fA-F]+$ ]] || return 1             # A hash is hex digits only: refuse anything else rather than put it in SQL
"${PROCONN[@]}" -N -B -r -e "select notes from global_notes where rechashvalue='$RECHASHVALUE'" 2>/dev/null
}

function store_note {
# Stores $1 as the note for $RECHASHVALUE. Text that is empty or only blanks removes the note (if there is one).
# The text never appears in the SQL as text: it travels as hex digits, so no character in a note (quote, semicolon,
# backslash, backtick, $ ...) can be mistaken for SQL, and none needs to be stripped or escaped.
local hex sql
[[ $RECHASHVALUE =~ ^[0-9a-fA-F]+$ ]] || return 1
if [[ -z ${1//[[:space:]]/} ]]; then
  sql="delete from global_notes where rechashvalue='$RECHASHVALUE'"
else
  hex=$(printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n')
  sql="replace into global_notes values ('$RECHASHVALUE', CONVERT(UNHEX('$hex') USING utf8mb4))"
fi
printf '%s\n' "$sql" | "${PROCONN[@]}" -N -B 2>/dev/null
}

function display_note {
local NOTETXT NEWTEXT
# Put any existing note into the file nano will edit, followed by a blank line to start typing on
NOTETXT=$(fetch_note)
if [[ -n $NOTETXT ]]; then
  printf '%s\n\n' "$NOTETXT" > "$CONFDIR/tmp/note.txt"
else
  : > "$CONFDIR/tmp/note.txt"
fi

nano -S +-1 "$CONFDIR/tmp/note.txt"     # -S means 'turn on soft wrapping of long lines'; the +-1 bit means 'open and immediately jump to end of file'
NEWTEXT=$(<"$CONFDIR/tmp/note.txt")
store_note "$NEWTEXT"
rm -f "$CONFDIR/tmp/note.txt" 2>/dev/null
}

function pick_composer {
local IFS=$'\n' name results exitStatus ; local -a namearray=()
mapfile -t results < <("${PROCONN[@]}" -N -B -e "select distinct gr.composer from global_recordings gr join global_notes gn on gr.rechashvalue=gn.rechashvalue order by gr.composer" 2>/dev/null)
for name in "${results[@]}"; do
    [[ -n "$name" ]] && namearray+=("$name" "$name" "off")
done
if [[ ${#namearray[@]} -eq 0 ]]; then
  dialog --backtitle "Giocoso View Notes" --title " No Notes " --msgbox "\nNo notes have been made for any recording in Giocoso's database, so there's nothing to display here." 8 80
  NOCOMPOSER=1
  return
fi
COMPOSER=$(dialog --stdout --no-tags --clear --backtitle "Giocoso View Notes" --title " Composers with Notes " --radiolist "Select a composer:" 10 90 0 "${namearray[@]}")
exitStatus=$?
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then
  NOCOMPOSER=1
elif [[ $exitStatus -eq 0 ]]; then
  if [[ -z $COMPOSER ]]; then
    NOCOMPOSER=1
  else
    NOCOMPOSER=0
  fi
else
  NOCOMPOSER=1
fi
}

function pick_recording {
local rechashvalue composition exitStatus
local -a namearray=()
local ESC_COMPOSER="${COMPOSER//\'/\'\'}"
while IFS=$'\t' read -r rechashvalue composition; do
    if [[ ${#composition} -gt 70 ]]; then composition="${composition:0:69}…"; fi     # Keep it on one line in the dialog
    [[ -n "$rechashvalue" ]] && namearray+=("$rechashvalue" "$composition" "off")
done < <("${PROCONN[@]}" -N -B -e "select distinct gr.rechashvalue, gr.composition from global_recordings gr join global_notes gn on gr.rechashvalue=gn.rechashvalue where gr.composer='$ESC_COMPOSER' order by gr.composition" 2>/dev/null)

if [[ ${#namearray[@]} -eq 0 ]]; then
  NORECORDING=1
  return
fi
RECHASHVALUE=$(dialog --stdout --no-tags --clear --backtitle "Giocoso View Notes" --title " Recordings with Notes " --radiolist "Select a recording:" 12 95 0 "${namearray[@]}")
exitStatus=$?
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then
  NORECORDING=1
elif [[ $exitStatus -eq 0 ]]; then
  NORECORDING=0
else
  NORECORDING=1
fi
}

for noteaction in "$@"; do
  case $noteaction in 
	edit_existing)
	  display_note;;
  view_any)
  	  pick_composer
  	  if [[ $NOCOMPOSER -eq 0 ]]; then
  		pick_recording		
  		if [[ $NORECORDING -eq 0 ]]; then
  		    IFS=$'\t' read -r DISPLAYCOMP DISPLAYWORK < <("${PROCONN[@]}" -N -B -e "select composer, composition from global_recordings where rechashvalue='$RECHASHVALUE' limit 1" 2>/dev/null)
		    
  		    fetch_note > "$CONFDIR/tmp/global_notes.txt"
  		    fold -s -w 88 < "$CONFDIR/tmp/global_notes.txt" > "$CONFDIR/tmp/global_noteswrapped.txt"
  		    $SEDPROG -i '1s/^/\n/' "$CONFDIR/tmp/global_noteswrapped.txt"    # Add a blank line to the start of the file for appearance's sake
		    
			NOTETITLE="Note for $DISPLAYCOMP - $DISPLAYWORK"
			if [[ ${#NOTETITLE} -gt 56 ]]; then NOTETITLE="${NOTETITLE:0:55}…"; fi     # The whole title has to fit the box, whatever the composer and work names are
		    
  		    dialog --exit-label "Exit" --extra-button --extra-label "Edit" --backtitle "Giocoso View Notes" --title " $NOTETITLE " --textbox "$CONFDIR/tmp/global_noteswrapped.txt" 20 95
  		    RESPONSE=$?

  		    if [[ $RESPONSE -eq 3 ]]; then
  		        nano -S +-1 "$CONFDIR/tmp/global_notes.txt"
				store_note "$(<"$CONFDIR/tmp/global_notes.txt")"
  		    fi
		    
  		    rm -f "$CONFDIR/tmp/global_notes.txt" 2>/dev/null
  		    rm -f "$CONFDIR/tmp/global_noteswrapped.txt" 2>/dev/null
  		  fi
  	  fi;;
  esac	  		
done

