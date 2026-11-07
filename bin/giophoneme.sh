#!/usr/bin/env bash
####################################################################
#
# giophoneme: A tool for managing the global_phoneme table and 
# thus allowing the user to tweak the pronunciation of composers 
# and compositions for pre-play announcements. Also to give the 
# user the ability to add new speech items or remove old ones. 
#
####################################################################

if [[ $1 == "user" ]]; then 
  PHONEME_TABLE="user_phonemes"
elif [[ $1 == "global" ]]; then
  PHONEME_TABLE="global_phonemes"
else
  PHONEME_TABLE="user_phonemes"
fi
	
CHOICE=$(dialog --no-tags --backtitle "Giocoso Announcement Management" \
  --title " Select Management Option " \
  --radiolist "\nWhat do you want to manage?" 16 80 2 \
  "composers" "Composers" ON \
  "compositions" "Compositions" OFF \
  "new" "New speech item" OFF \
  "old" "Delete speech item" OFF \
  3>&1 1>&2 2>&3)

DIALOGSTATUS=$?

if [[ $DIALOGSTATUS -ne 0 ]]; then
  return
fi

if [[ $CHOICE == "old" ]]; then

  LETTER=$(dialog --no-tags --backtitle "Giocoso Announcement Management" \
    --title " Select Initial Letter " \
    --radiolist "Select the initial letter of the speech item:" 22 50 16 \
    "A" "A" ON \
    "B" "B" OFF \
    "C" "C" OFF \
    "D" "D" OFF \
    "E" "E" OFF \
    "F" "F" OFF \
    "G" "G" OFF \
    "H" "H" OFF \
    "I" "I" OFF \
    "J" "J" OFF \
    "K" "K" OFF \
    "L" "L" OFF \
    "M" "M" OFF \
    "N" "N" OFF \
    "O" "O" OFF \
    "P" "P" OFF \
    "Q" "Q" OFF \
    "R" "R" OFF \
    "S" "S" OFF \
    "T" "T" OFF \
    "U" "U" OFF \
    "V" "V" OFF \
    "W" "W" OFF \
    "X" "X" OFF \
    "Y" "Y" OFF \
    "Z" "Z" OFF \
    "Other" "Other" OFF \
    3>&1 1>&2 2>&3)

  DIALOGSTATUS=$?

  if [[ $DIALOGSTATUS -ne 0 ]]; then
    return
  fi

  DIALOGFILE="$CONFDIR/tmp/phonemedelete.txt"

  if [[ $LETTER == "Other" ]]; then
    DELETEQUERY="select phrase
                 from $PHONEME_TABLE
                 where phrase regexp '^[^A-Za-z]'
                 order by phrase"
  else
    DELETEQUERY="select phrase
                 from $PHONEME_TABLE
                 where phrase like '$LETTER%'
                 order by phrase"
  fi

  "${PROCONN[@]}" -N -B -e "$DELETEQUERY" |
  awk '{
    phrase=$0
    gsub(/\\/, "\\\\", phrase)
    gsub(/"/, "\\\"", phrase)
    print "\"" phrase "\""
    print "\"" phrase "\""
    print "OFF"
  }' > "$DIALOGFILE"

  DELETEITEMS=$(dialog --no-tags \
    --no-hot-list \
	--separate-output \
    --backtitle "Giocoso Announcement Management" \
    --title " Delete Speech Items " \
    --checklist "Select the speech items to delete:" \
    22 90 18 \
    --file "$DIALOGFILE" \
    3>&1 1>&2 2>&3)

  DIALOGSTATUS=$?

  if [[ $DIALOGSTATUS -ne 0 ]]; then
    return
  fi

  while IFS= read -r PHRASE; do
    [[ -z $PHRASE ]] && continue

    SQLPHRASE="${PHRASE//\'/\'\'}"

    "${PROCONN[@]}" -N -B -e \
      "delete from $PHONEME_TABLE where phrase='$SQLPHRASE'" 2>/dev/null

  done <<< "$DELETEITEMS"

  return

fi

if [[ $CHOICE == "new" ]]; then

  PHRASE=""
  VOICE=""
  PHONEME=""

  while true; do

    NEWITEM=$(dialog --backtitle "Giocoso Announcement Management" \
      --title " New Speech Item " \
      --extra-button \
      --extra-label "Say" \
      --form "Enter the new speech item details:" 14 70 0 \
      "Phrase:"  1 1 "$PHRASE"  1 12 50 128 \
      "Voice:"   2 1 "$VOICE"   2 12 30 64 \
      "Phoneme:" 3 1 "$PHONEME" 3 12 50 256 \
      3>&1 1>&2 2>&3)

    DIALOGSTATUS=$?

    PHRASE=$(printf '%s\n' "$NEWITEM" | sed -n '1p')
    VOICE=$(printf '%s\n' "$NEWITEM" | sed -n '2p')
    PHONEME=$(printf '%s\n' "$NEWITEM" | sed -n '3p')

    if [[ $DIALOGSTATUS -eq 3 ]]; then

      if [[ -n $PHONEME ]]; then
        SPEAKTEXT="$PHONEME"
      else
        SPEAKTEXT="$PHRASE"
      fi

      if [[ -n $VOICE ]]; then
        SPEAKVOICE="$VOICE"
      else
        SPEAKVOICE="Daniel"
      fi

      say -v "$SPEAKVOICE" -r $VSPEED "$SPEAKTEXT"
      continue

    elif [[ $DIALOGSTATUS -eq 0 ]]; then

      SQLPHRASE="${PHRASE//\'/\'\'}"
      SQLVOICE="${VOICE//\'/\'\'}"
      SQLPHONEME="${PHONEME//\'/\'\'}"

      "${PROCONN[@]}" -N -B -e "insert into $PHONEME_TABLE (phrase, voice, phoneme) values ('$SQLPHRASE', nullif('$SQLVOICE',''), nullif('$SQLPHONEME',''))" 2>/dev/null
      return

    else
      return
    fi

  done

fi

if [[ $CHOICE == "compositions" ]]; then

  LETTER=$(dialog --no-tags --backtitle "Giocoso Announcement Management" \
    --title " Select Initial Letter " \
    --radiolist "\nSelect the first letter of the composition name:" 18 80 16 \
    "A" "A" ON \
    "B" "B" OFF \
    "C" "C" OFF \
    "D" "D" OFF \
    "E" "E" OFF \
    "F" "F" OFF \
    "G" "G" OFF \
    "H" "H" OFF \
    "I" "I" OFF \
    "J" "J" OFF \
    "K" "K" OFF \
    "L" "L" OFF \
    "M" "M" OFF \
    "N" "N" OFF \
    "O" "O" OFF \
    "P" "P" OFF \
    "Q" "Q" OFF \
    "R" "R" OFF \
    "S" "S" OFF \
    "T" "T" OFF \
    "U" "U" OFF \
    "V" "V" OFF \
    "W" "W" OFF \
    "X" "X" OFF \
    "Y" "Y" OFF \
    "Z" "Z" OFF \
    "Other" "Other" OFF \
    3>&1 1>&2 2>&3)

  DIALOGSTATUS=$?

  if [[ $DIALOGSTATUS -ne 0 ]]; then
    return
  fi
fi

DIALOGFILE="$CONFDIR/tmp/phonemelist.txt"
LASTPHRASE=""
PROCESSFILTER=""

while true; do

  if [[ $CHOICE == "composers" ]]; then
	ITEMTEXT="Composer"  

    "${PROCONN[@]}" -N -B -e "
    select gp.phrase, if(nullif(gp.phoneme,'') is not null or gp.voice is not null,1,0)
    from $PHONEME_TABLE gp
    where gp.phrase in (
      select distinct composer
      from global_recordings
    )
    order by gp.phrase
    " |
    awk -F '\t' '{
      phrase=$1
      display=$1
      gsub(/\\/, "\\\\", phrase)
      gsub(/"/, "\\\"", phrase)
      if ($2 == 1) display=display " †"
      gsub(/\\/, "\\\\", display)
      gsub(/"/, "\\\"", display)
      print "\"" phrase "\""
      print "\"" display "\""
      print "OFF"
    }' > "$DIALOGFILE"

  elif [[ $LETTER == "Other" ]]; then

    "${PROCONN[@]}" -N -B -e "
    select gp.phrase, if(nullif(gp.phoneme,'') is not null or gp.voice is not null,1,0)
    from $PHONEME_TABLE gp
    where gp.phrase regexp '^[^A-Za-z]'
    $PROCESSFILTER
    and gp.phrase in (
      select distinct trim(left(composition, char_length(composition) - locate('(', reverse(composition))))
      from global_recordings
    )
    order by gp.phrase
    " |
    awk -F '\t' '{
      phrase=$1
      if ($2 == 1)
        display=sprintf("%-72s", "† " substr($1,1,70))
      else
        display=sprintf("%-72s", "  " substr($1,1,70))
      gsub(/\\/, "\\\\", phrase)
      gsub(/"/, "\\\"", phrase)
      gsub(/\\/, "\\\\", display)
      gsub(/"/, "\\\"", display)
      print "\"" phrase "\""
      print "\"" display "\""
      print "OFF"
    }' > "$DIALOGFILE"

  else

    "${PROCONN[@]}" -N -B -e "
    select gp.phrase, if(nullif(gp.phoneme,'') is not null or gp.voice is not null,1,0)
    from $PHONEME_TABLE gp
    where gp.phrase like '$LETTER%'
    $PROCESSFILTER
    and gp.phrase in (
      select distinct trim(left(composition, char_length(composition) - locate('(', reverse(composition))))
      from global_recordings
    )
    order by gp.phrase
    " |
    awk -F '\t' '{
      phrase=$1
      if ($2 == 1)
        display=sprintf("%-72s", "† " substr($1,1,70))
      else
        display=sprintf("%-72s", "  " substr($1,1,70))
      gsub(/\\/, "\\\\", phrase)
      gsub(/"/, "\\\"", phrase)
      gsub(/\\/, "\\\\", display)
      gsub(/"/, "\\\"", display)
      print "\"" phrase "\""
      print "\"" display "\""
      print "OFF"
    }' > "$DIALOGFILE"

  fi

  if [[ $CHOICE == "compositions" ]]; then
	  ITEMTEXT="Composition"

    if [[ -z $PROCESSFILTER ]]; then
      FILTERBUTTON="Only Non-Processed"
    else
      FILTERBUTTON="Show All"
    fi

    if [[ -n $LASTPHRASE ]]; then
      CHOSENPHRASE=$(dialog --no-tags \
        --no-hot-list \
        --backtitle "Giocoso Announcement Management - Press ESC to return to the main menu" \
        --title " Select $ITEMTEXT " \
        --default-item "$LASTPHRASE" \
        --extra-button \
        --extra-label "$FILTERBUTTON" \
        --radiolist "\nSelect the $ITEMTEXT name whose pronunciation you want to check:" \
        22 90 18 \
        --file "$DIALOGFILE" \
        3>&1 1>&2 2>&3)
    else
      CHOSENPHRASE=$(dialog --no-tags \
        --no-hot-list \
        --backtitle "Giocoso Announcement Management - Press ESC to return to the main menu" \
        --title " Select $ITEMTEXT " \
        --extra-button \
        --extra-label "$FILTERBUTTON" \
        --radiolist "\nSelect the $ITEMTEXT name whose pronunciation you want to check:" \
        22 90 18 \
        --file "$DIALOGFILE" \
        3>&1 1>&2 2>&3)
    fi

  else

    if [[ -n $LASTPHRASE ]]; then
      CHOSENPHRASE=$(dialog --no-tags \
        --backtitle "Giocoso Announcement Management - Press ESC to return to the main menu" \
        --title " Select $ITEMTEXT " \
        --default-item "$LASTPHRASE" \
        --radiolist "\nSelect the $ITEMTEXT name whose pronunciation you want to check:" \
        22 90 18 \
        --file "$DIALOGFILE" \
        3>&1 1>&2 2>&3)
    else
      CHOSENPHRASE=$(dialog --no-tags \
        --backtitle "Giocoso Announcement Management - Press ESC to return to the main menu" \
        --title " Select $ITEMTEXT " \
        --radiolist "\nSelect the $ITEMTEXT name whose pronunciation you want to check:" \
        22 90 18 \
        --file "$DIALOGFILE" \
        3>&1 1>&2 2>&3)
    fi

  fi

  DIALOGSTATUS=$?

  if [[ $CHOICE == "compositions" && $DIALOGSTATUS -eq 3 ]]; then
    if [[ -z $PROCESSFILTER ]]; then
      PROCESSFILTER="and nullif(gp.phoneme,'') is null and gp.voice is null"
      LASTPHRASE=""
    else
      PROCESSFILTER=""
    fi
    continue
  fi

  if [[ $DIALOGSTATUS -ne 0 ]]; then
    return
  fi

  if [[ -z $CHOSENPHRASE ]]; then
    continue
  fi

  LASTPHRASE="$CHOSENPHRASE"
  COMPOSER="$CHOSENPHRASE"

  SQLCOMPOSER="${COMPOSER//\'/\'\'}"

  SPOKENTEXT=$("${PROCONN[@]}" -N -B -e \
    "select ifnull(nullif(phoneme,''),phrase) from $PHONEME_TABLE where phrase='$SQLCOMPOSER'" 2>/dev/null)

  SOUNDVOICE=$("${PROCONN[@]}" -N -B -e \
    "select ifnull(voice,'Daniel') from $PHONEME_TABLE where phrase='$SQLCOMPOSER'" 2>/dev/null)

  while true; do
    say -v "$SOUNDVOICE" -r $VSPEED "$SPOKENTEXT" &

    dialog --backtitle "Giocoso Announcement Management - Press ESC to return to the main menu" \
      --title " Composer Pronunciation " \
      --yes-label "Good" \
      --no-label "Bad" \
      --extra-button \
      --extra-label "Select Voice" \
      --yesno "\nWas this an acceptable pronunciation of:\n\n$COMPOSER" 10 60

    DIALOGSTATUS=$?

    if [[ $DIALOGSTATUS -eq 0 ]]; then

      SQLSPOKENTEXT="${SPOKENTEXT//\'/\'\'}"

      if [[ $SOUNDVOICE == "Daniel" ]]; then
        "${PROCONN[@]}" -N -B -e "update $PHONEME_TABLE set phoneme='$SQLSPOKENTEXT', voice=null where phrase='$SQLCOMPOSER'" 2>/dev/null

      elif [[ $SPOKENTEXT == "$COMPOSER" ]]; then
        "${PROCONN[@]}" -N -B -e "update $PHONEME_TABLE set phoneme=null, voice='$SOUNDVOICE' where phrase='$SQLCOMPOSER'" 2>/dev/null

      else
        "${PROCONN[@]}" -N -B -e "update $PHONEME_TABLE set phoneme='$SQLSPOKENTEXT', voice='$SOUNDVOICE' where phrase='$SQLCOMPOSER'" 2>/dev/null
      fi

      break

    elif [[ $DIALOGSTATUS -eq 1 ]]; then

      ALTERNATIVE="$SPOKENTEXT"

      while true; do
        ALTERNATIVE=$(dialog --backtitle "Giocoso Announcement Management - Press ESC to return to the main menu" \
          --title " Alternative Pronunciation " \
          --extra-button \
          --extra-label "Say" \
          --no-cancel \
          --inputbox "\nType an alternative pronunciation for:\n\n$COMPOSER" 12 60 "$ALTERNATIVE" \
          3>&1 1>&2 2>&3)

        ALTSTATUS=$?

        if [[ $ALTSTATUS -eq 3 ]]; then
          say -v "$SOUNDVOICE" -r $VSPEED "$ALTERNATIVE"
          continue

        elif [[ $ALTSTATUS -eq 0 ]]; then
          SPOKENTEXT="$ALTERNATIVE"
          break

        elif [[ $ALTSTATUS -eq 255 ]]; then
          return
        fi
      done

      continue

    elif [[ $DIALOGSTATUS -eq 3 ]]; then

        SELECTEDVOICE=$(dialog --no-tags \
          --backtitle "Giocoso Announcement Management - Press ESC to return to the pronunciation form" \
          --title " Select Voice " \
          --radiolist "Select the voice to use:" 18 60 10 \
          "Daniel" "Daniel - English" ON \
          "Anna" "Anna - German" OFF \
		  "Thomas" "Thomas - French" OFF \
		  "Alice" "Alice - Italian" OFF \
		  "Mónica" "Mónica - Spanish" OFF \
		  "Milena" "Milena - Russian" OFF \
		  "Ellen" "Ellen - Belgian" OFF \
          "Zosia" "Zosia - Polish" OFF \
          "Zuzana" "Zuzana - Czech" OFF \
          "Alva" "Alva - Danish/Swedish" OFF \
          "Satu" "Satu - Finnish" OFF \
	      "Joana" "Joana - Portuguese" OFF \
          "Melina" "Melina - Greek" OFF \
          "Tünde" "Tünde - Hungarian" OFF \
		  "Kyoko" "Kyoko - Japanese" OFF \
          "Tingting" "Tingting - Chinese" OFF \
          "Yelda" "Yelda - Turkish" OFF \
          3>&1 1>&2 2>&3)

      VOICESTATUS=$?

      if [[ $VOICESTATUS -eq 0 && -n $SELECTEDVOICE ]]; then
        SOUNDVOICE="$SELECTEDVOICE"

        if [[ $SPOKENTEXT == "$COMPOSER" ]]; then
          SPOKENTEXT="$COMPOSER"
        fi

        continue
      fi

    elif [[ $DIALOGSTATUS -eq 255 ]]; then
      return
    fi

  done

done