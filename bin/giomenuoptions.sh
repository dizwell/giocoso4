#!/usr/bin/env bash
####################################################################
#
# A function to write various menu options onto the screen
#
####################################################################
SPACER="      "
escape_char=$(printf "\u1b")

# Check to see if ffmpeg is already running
####################################################################
FFMPEGCOUNT=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" 2>/dev/null | $GREPPROG -v $GREPPROG 2>/dev/null | wc -l)     
####################################################################
  if [[ $1 == play && $FFMPEGCOUNT -eq 0 ]]; then	  
    # Check to see if any global pauses exist and flash a message about them if so
	# ======================================================================================================
	RESUMPTION=$("${PROCONN[@]}" -N -B -e "select count(*) from global_pauses")
	if [[ $RESUMPTION -ne 0 ]]; then 
	  tput cup 19 7; tput setaf 10; echo -en '\e[5mThere are paused plays\e[0m\n'
	  tput cup 20 7; tput setaf 10; echo -en '\e[5mPress [Spacebar] to resume\e[0m\n'
	fi	
	
    # ======================================================================================================
    tput cup  5 4
    tput setaf $HOTKEY; echo -en "\e[7mPlay\e[0m"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "D"; tput setaf $DRAWLINES; echo -en "atabase"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "eports"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dministration"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
    # ======================================================================================================
    tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) Play music with defaults"
    tput cup  9 4;                       echo -e "2) Play music from selection filters"
    tput cup 10 4;                       echo -e "3) Play music in specified folder"
    tput cup 11 4;                       echo -e "4) Play music by advanced SQL selection"
    tput cup 12 4;                       echo -e "5) Play music from a playlist"
    tput cup 13 4;                       echo -e "6) Resume a paused play"
	tput cup 14 4;                       echo -e "7) Delete stored queries"
    tput cup 22 4; tput setaf $ALERT;    echo -e "X) Exit the program"
  
    until [[ $option == q ]]; do
      tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
      tput cup 25 24; tput cvvis; 
	  IFS= read -n 1 -s -r option
      if [[ $option == $'\e' ]]; then
        seq="$option"
        while read -rsn1 -t 0.001 ch; do
          seq+="$ch"
        done
        option="$seq"
      fi
      case $option in
		" ") FFMPEGCOUNT=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l); if [ $FFMPEGCOUNT -eq 0 ]; then source "$CONFDIR/bin/gioglobresume.sh"; gmenuoptions play; fi;;
        "" ) FFMPEGCOUNT=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l); if [ $FFMPEGCOUNT -eq 0 ]; then source "$CONFDIR/bin/gioplay.sh" default; gmenuoptions play; fi;;
        1 ) FFMPEGCOUNT=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l); if [ $FFMPEGCOUNT -eq 0 ]; then source "$CONFDIR/bin/gioplay.sh" default; gmenuoptions play; fi;;
        2 ) FFMPEGCOUNT=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l); if [ $FFMPEGCOUNT -eq 0 ]; then source "$CONFDIR/bin/gioplay.sh" filter; gmenuoptions play; fi;;
        3 ) FFMPEGCOUNT=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l); if [ $FFMPEGCOUNT -eq 0 ]; then source "$CONFDIR/bin/gioplay.sh" direct; gmenuoptions play; fi;;
        4 ) FFMPEGCOUNT=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l); if [ $FFMPEGCOUNT -eq 0 ]; then source "$CONFDIR/bin/gioplay.sh" sql; gmenuoptions play; fi;;
        5 ) FFMPEGCOUNT=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l); if [ $FFMPEGCOUNT -eq 0 ]; then source "$CONFDIR/bin/gioplay.sh" playlist; gmenuoptions play; fi;;
        6 ) FFMPEGCOUNT=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l); if [ $FFMPEGCOUNT -eq 0 ]; then source "$CONFDIR/bin/gioglobresume.sh"; gmenuoptions play; fi;;
		7 ) source "$CONFDIR/bin/gioqrydel.sh"; gmenuoptions play;;
        P|p ) clear; gmenuoptions play;;
        D|d ) clear; gmenuoptions database;;
        R|r ) clear; gmenuoptions reports;;
        A|a ) clear; gmenuoptions admin;;
        Q|q|X|x ) option=q; clear; tput cvvis; reset;;
        $'\e[D') gmenuoptions quit;;
        $'\e[C') gmenuoptions database;;
      esac
    done
  elif [[ $1 == play && $FFMPEGCOUNT -ne 0 ]]; then
    # ======================================================================================================
    tput cup  5 4
    tput setaf $HOTKEY; echo -en "\e[7mPlay\e[0m"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "D"; tput setaf $DRAWLINES; echo -en "atabase"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "eports"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dministration"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
    # ======================================================================================================
    tput cup  8 4; tput setaf $INFOTEXT;  echo "Music already playing in another session..."
    tput cup 22 4; tput setaf $ALERT;    echo -e "X) Exit the program"
    
  until [[ $option == q ]]; do
    tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
    tput cup 25 24; tput cvvis; read -n 1 -s -r option
    if [[ $option == $'\e' ]]; then
      seq="$option"
      while read -rsn1 -t 0.001 ch; do
        seq+="$ch"
      done
      option="$seq"
    fi
    case $option in
      P|p ) clear; gmenuoptions play;;
      D|d ) clear; gmenuoptions database;;
      R|r ) clear; gmenuoptions reports;;
      A|a ) clear; gmenuoptions admin;;
      Q|q|X|x ) option=q; clear; tput cvvis; reset;;
      $'\e[D') gmenuoptions quit;;
      $'\e[C') gmenuoptions database;;
    esac
  done 
  elif [[ $1 == database ]]; then
    # ======================================================================================================
    tput cup  5 4
    tput setaf $HOTKEY; echo -en "P"; tput setaf $DRAWLINES; echo -en "lay"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "\e[7mDatabase\e[0m"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "eports"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dministration"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
    # ======================================================================================================
    tput cup  8 4; tput setaf $MAINTEXT; echo "1) Fast Scan for new recordings"
    tput cup  9 4;                       echo "2) Full Scan all recordings"
    tput cup 10 4;                       echo "3) Move plays & notes between databases"
	tput cup 11 4;                       echo "4) Backup the database"
	tput cup 12 4;                       echo "5) Restore the database"
    tput cup 13 4;                       echo "6) View all recording notes"
	tput cup 14 4;                       echo "7) Clear all recording pauses"
	tput cup 15 4; 						 echo "8) Manage the announcements engine"
	if [[ $(whoami) == "hjr" ]]; then tput cup 16 4;                       echo "9) Manage the default announcements (lossy)"; fi
    tput cup 22 4; tput setaf $ALERT;    echo -e "X) Exit the program"
  
    until [[ $option == q ]]; do
      tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
      tput cup 25 24; tput cvvis; read -n 1 -s -r option
      if [[ $option == $'\e' ]]; then
        seq="$option"
        while read -rsn1 -t 0.001 ch; do
          seq+="$ch"
        done
        option="$seq"
      fi
      case $option in
      "" ) source "$CONFDIR/bin/giorefreshdb.sh"; gmenuoptions database;;
      1 ) source "$CONFDIR/bin/giorefreshdb.sh" NODIR fast; gmenuoptions database;;
      2 ) source "$CONFDIR/bin/giorefreshdb.sh" NODIR full; gmenuoptions database;;
      3 ) source "$CONFDIR/bin/giobkpdb.sh" move; gmenuoptions database;;
      4 ) source "$CONFDIR/bin/giobkpdb.sh" backup; gmenuoptions database;;
      5 ) source "$CONFDIR/bin/giobkpdb.sh" restore; gmenuoptions database;;
      6 ) source "$CONFDIR/bin/gioretnote.sh" view_any; gmenuoptions database;;
	  7 ) dialog --backtitle "Giocoso Pauses" --yesno "Clear ALL paused recordings?\n\nThis cannot be undone." 9 60
          if [[ $? -eq 0 ]]; then
            "${PROCONN[@]}" -e "delete from global_pauses"
            dialog --stdout --backtitle "Giocoso Pauses" --msgbox "All recording pauses have now been cleared." 8 80
          fi
          gmenuoptions database;;
	  8 ) source "$CONFDIR/bin/giophoneme.sh" user; gmenuoptions database;;
  	  9 ) if [[ $(whoami) == "hjr" ]]; then source "$CONFDIR/bin/giophoneme.sh" global; gmenuoptions database; fi;;
      P|p ) clear; gmenuoptions play;;
      D|d ) clear; gmenuoptions database;;
      R|r ) clear; gmenuoptions reports;;
      A|a ) clear; gmenuoptions admin;;
      Q|q|X|x ) option=q; clear; tput cvvis; reset;;
      $'\e[D') gmenuoptions play;;
      $'\e[C') gmenuoptions reports;;
      esac
    done
    
  elif [[ $1 == reports ]]; then
    # ======================================================================================================
    tput cup  5 4
    tput setaf $HOTKEY; echo -en "P"; tput setaf $DRAWLINES; echo -en "lay"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "D"; tput setaf $DRAWLINES; echo -en "atabase"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "\e[7mReports\e[0m"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dministration"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
    # ======================================================================================================
    tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) Aggregate Statistics"
	tput cup  9 4;                       echo -e "2) Advanced Reporting by SQL"
	tput cup 10 4;                       echo -e "3) Days since composer last played"
	tput cup 11 4;                       echo -e "4) Days since recording last played"
    tput cup 12 4;                       echo "5) Top composers and genre reports"
	tput cup 13 4;                       echo "6) Plays by device and operating system"
	tput cup 14 4;                       echo "7) Play History (Recent & Complete)"
	tput cup 15 4;                       echo "8) All Recordings listing"
	tput cup 16 4;                       echo "9) Export plays & recordings to CSV"    
    tput cup 22 4; tput setaf $ALERT;    echo -e "X) Exit the program"
  
    until [[ $option == q ]]; do
      tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
      tput cup 25 24; tput cvvis; read -n 1 -s -r option
      if [[ $option == $'\e' ]]; then
        seq="$option"
        while read -rsn1 -t 0.001 ch; do
          seq+="$ch"
        done
        option="$seq"
      fi
    case $option in
     "" ) source "$CONFDIR/bin/giorptaggstats.sh"; gmenuoptions reports;;
      1 ) source "$CONFDIR/bin/giorptaggstats.sh"; gmenuoptions reports;;
	  2 ) source "$CONFDIR/bin/giorptadvsql.sh"; gmenuoptions reports;;
	  3 ) source "$CONFDIR/bin/giorptlastplayed.sh" composer; gmenuoptions reports;;
	  4 ) source "$CONFDIR/bin/giorptlastplayed.sh" composition; gmenuoptions reports;;
      5 ) source "$CONFDIR/bin/giorpttopcomp.sh"; gmenuoptions reports;;
      6 ) source "$CONFDIR/bin/giorptdevos.sh"; gmenuoptions reports;;
	  7 ) source "$CONFDIR/bin/giorptplayhist.sh"; gmenuoptions reports;;
	  8 ) source "$CONFDIR/bin/giorptallrecs.sh"; gmenuoptions reports;;
	  9 ) "${PROCONN[@]}" -e "select * from global_plays order by composer" 2>/dev/null | $SEDPROG 's/\t/|/g' > "$CONFDIR/txt/export_plays.csv"
	            PLAYSTAT=("${PIPESTATUS[@]}")
	            "${PROCONN[@]}" -e "select * from global_recordings order by composer" 2>/dev/null | $SEDPROG 's/\t/|/g' > "$CONFDIR/txt/export_recordings.csv"
	            RECSTAT=("${PIPESTATUS[@]}")
	            if [[ ${PLAYSTAT[0]} -eq 0 && ${PLAYSTAT[1]} -eq 0 && ${RECSTAT[0]} -eq 0 && ${RECSTAT[1]} -eq 0 ]]; then
	              dialog --backtitle "Report Plays & Recordings to CSV" --title " Export to CSV Complete " --msgbox "\nYour plays and recordings data can now be found in: \n\n    $CONFDIR/txt/ \n\n...as files: \n\nexport_plays.csv; and \nexport_recordings.csv\n\nDespite the file extensions, these are **pipe delimited** files!" 17 80
	            else
	              rm -f "$CONFDIR/txt/export_plays.csv" "$CONFDIR/txt/export_recordings.csv"
	              dialog --backtitle "Report Plays & Recordings to CSV" --title " Export to CSV Failed " --msgbox "\nThe export did not complete.\n\nPlease check that the database is running and that you can write to: \n\n    $CONFDIR/txt/" 14 80
	            fi
	            gmenuoptions reports;;
    P|p ) clear; gmenuoptions play;;
    D|d ) clear; gmenuoptions database;;
    R|r ) clear; gmenuoptions reports;;
    A|a ) clear; gmenuoptions admin;;
    Q|q|X|x ) option=q; clear; tput cvvis; reset;;
    $'\e[D') gmenuoptions database;;
    $'\e[C') gmenuoptions admin;;
    esac
  done
  
  elif [[ $1 == admin ]]; then
    # ======================================================================================================
    tput cup  5 4
    tput setaf $HOTKEY; echo -en "P"; tput setaf $DRAWLINES; echo -en "lay"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "D"; tput setaf $DRAWLINES; echo -en "atabase"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "eports"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "\e[7mAdministration\e[0m"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
    # ======================================================================================================
    tput cup  8 4; tput setaf $MAINTEXT; echo "1) Create or Edit the Configuration file"
    tput cup  9 4;                       echo "2) Manage Exclusions"
    tput cup 10 4;                       echo "3) Manage Timebar Exemptions"
	tput cup 11 4;                       echo "4) List all Exclusions and Exemptions"
    tput cup 12 4;                       echo "5) Display the Giocoso software license"
    tput cup 13 4;                       echo "6) Test Audio Device configuration"
    tput cup 14 4;                       echo "7) Reset PulseAudio Server (requires sudo)"
    tput cup 15 4;                       echo "8) Change the program colour scheme"
    tput cup 22 4; tput setaf $ALERT; echo -e "X) Exit the program"
  
    until [[ $option == q ]]; do
      tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
      tput cup 25 24; tput cvvis; read -n 1 -s -r option
    if [[ $option == $'\e' ]]; then
      seq="$option"
      while read -rsn1 -t 0.001 ch; do
        seq+="$ch"
      done
      option="$seq"
    fi
    case $option in
      1 ) source "$CONFDIR/bin/gioconfconstruct.sh"; sleep .5; parse_config; gmenuoptions admin;;
      2 ) source "$CONFDIR/bin/gioexcludes.sh"; gmenuoptions admin;;
      3 ) source "$CONFDIR/bin/gioexempts.sh"; gmenuoptions admin;;
	  4 ) source "$CONFDIR/bin/giorptexcludes.sh"; gmenuoptions admin;;
      5 ) if [[ ! -d "$CONFDIR/tmp" ]]; then mkdir -p "$CONFDIR/tmp"; fi
          if [[ ! -s "$CONFDIR/tmp/license.txt" ]]; then
            for attempt in {1..5}; do
              if wget -q --tries=1 "https://bbritten.com/software/giocoso4/gpl-v2.0.txt" -O "$CONFDIR/tmp/license.txt" && [[ -s "$CONFDIR/tmp/license.txt" ]]; then
                break
              fi
              sleep 1
            done
          fi
          if [[ -s "$CONFDIR/tmp/license.txt" ]]; then
            fmt -w 90 < "$CONFDIR/tmp/license.txt" > "$CONFDIR/tmp/licensewrapped.txt"
            $SEDPROG -i 's/\\n/\n/g' "$CONFDIR/tmp/licensewrapped.txt"  # Sorts out spurious extra blank lines, replacing them with singles
            $SEDPROG -i '1s/^/\n/' "$CONFDIR/tmp/licensewrapped.txt"    # Add a blank line to the start of the file for appearance's sake
            dialog --backtitle "Giocoso GPL v2 Software Licence" --title " Text of the GPLv2 Licence " --ok-label "OK" --extra-button --extra-label "Cancel" --textbox "$CONFDIR/tmp/licensewrapped.txt" 20 95
          else
            rm -f "$CONFDIR/tmp/license.txt"
            dialog --backtitle "Giocoso GPL v2 Software Licence" --msgbox "\nThe licence text could not be downloaded. Please check your internet connection and try again." 9 70
          fi
          gmenuoptions admin ;;
		  6 ) source "$CONFDIR/bin/gioaudtst.sh"; gmenuoptions admin;;
      7 ) if [[ $(uname -a) == *"Darwin"* ]]; then
	        PULSEPID=$(pgrep pulseaudio)
		  else
	        PULSEPID=$(pidof pulseaudio)
		  fi
		  if [[ -n $PULSEPID ]]; then
			sudo kill -9 $PULSEPID
			sleep 5
		  fi
		  gmenuoptions admin;; 
      8 ) source "$CONFDIR/bin/giocolour.sh"; gmenuoptions admin;;
      P|p ) clear; gmenuoptions play;;
      D|d ) clear; gmenuoptions database;;
      R|r ) clear; gmenuoptions reports;;
      A|a ) clear; gmenuoptions admin;;
  Q|q|X|x ) option=q; clear; tput cvvis; reset;;
   $'\e[D') gmenuoptions reports;;
   $'\e[C') gmenuoptions quit;;
    esac
  done

  elif [[ $1 == quit ]]; then
    # ======================================================================================================
    tput cup  5 4
    tput setaf $HOTKEY; echo -en "P"; tput setaf $DRAWLINES; echo -en "lay"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "D"; tput setaf $DRAWLINES; echo -en "atabase"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "eports"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dministration"; echo -en "$SPACER"
    tput setaf $HOTKEY; echo -en "\e[7mQuit\e[0m"
    # ======================================================================================================
    until [[ $option == q ]]; do
      tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
      tput cup 25 24; tput cvvis; read -n 1 -s -r option
      if [[ $option == $'\e' ]]; then
        seq="$option"
        while read -rsn1 -t 0.001 ch; do
          seq+="$ch"
        done
        option="$seq"
      fi
    case $option in
      ""  ) exit_program ;;
      P|p ) clear; gmenuoptions play;;
      D|d ) clear; gmenuoptions database;;
      R|r ) clear; gmenuoptions reports;;
      A|a ) clear; gmenuoptions admin;;
      Q|q|X|x ) option=q; clear; tput cvvis; reset;;
      $'\e[D') gmenuoptions admin;;
      $'\e[C') gmenuoptions play;;
      esac
    done
    
  elif [[ $1 == minig ]]; then
    if [[ $FFMPEGCOUNT -eq 0 ]]; then 
      tput cup 5 4; tput setaf $MAINTEXT; echo "P) Play Music"
      tput cup 6 4; tput setaf $MAINTEXT; echo "F) Filter Selection"
      tput cup 7 4; echo "1) Select a PulseAudio Server"
      tput cup 8 4; echo "2) Set up PulseAudio Server details"
      tput cup 9 4; echo "3) Refresh screen"
      tput cup 10 4; echo "X) Exit"
      tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER
    else 
      tput cup 5 4; tput setaf $MAINTEXT; echo "Music already being played:"; 
      trim() {
      local var="$*"
      var="${var#"${var%%[![:space:]]*}"}"
      var="${var%"${var##*[![:space:]]}"}"
      printf '%s' "$var"
      }
      if [[ -f "$CONFDIR/txt/mgioplay.txt" ]]; then
        mapfile -t PLAYLINES < "$CONFDIR/txt/mgioplay.txt"
        if [[ ${#PLAYLINES[@]} -ge 4 ]]; then
          # mgioplay.txt holds one Key@Value per line. Read it once and split each line at its FIRST @ (so an @ inside
          # a title survives), matching the key exactly (so a performer called "Recording..." can't be mistaken for the
          # Recording line). No cat, grep or awk is started at all.
          plgline="" plgkey="" plgvalue=""
          COMPOSER="" RECORDING="" DISTART="" PERFORMERS="" PREVIOUS_PLAYS="" ENDINGAT="" RPGAIN="" LASTPLAY="" RECORDING_YEAR=""
          for plgline in "${PLAYLINES[@]}"; do
            plgkey=${plgline%%@*}; plgvalue=${plgline#*@}
            case $plgkey in
              "Composer"           ) COMPOSER=$plgvalue;;
              "Recording"          ) RECORDING=${plgvalue%%(*}; RECORDING_YEAR=${plgvalue: -5:4};;
              "Distinguishing"     ) DISTART=$plgvalue;;
              "Performers"         ) PERFORMERS=$plgvalue;;
              "Previous plays"     ) PREVIOUS_PLAYS=$plgvalue;;
              "Ending at"          ) ENDINGAT=$plgvalue;;
              "ReplayGain Applied" ) RPGAIN=$plgvalue;;
              "LastPlay"           ) LASTPLAY=$plgvalue;;
            esac
          done
          unset plgline plgkey plgvalue

          # Strip the instrument/role brackets from the distinguishing artist, and use the FULL name
          # to remove it from the performers list. Only then truncate for display.
          DISTART=$(echo "$DISTART" | awk -F '(' '{print $1}')

          PERFORMERS=$($SEDPROG -e 's/([^()]*)//g' <<< "$PERFORMERS" 2>/dev/null)
          PERFORMERS=${PERFORMERS//"$DISTART"/}
          PERFORMERS=${PERFORMERS//,  , /, }
          PERFORMERS=$(trim "$PERFORMERS")
          [[ "${PERFORMERS: -1}" == "," ]] && PERFORMERS="${PERFORMERS:: -1}"
          [[ "${PERFORMERS:0:2}" == ", " ]] && PERFORMERS="${PERFORMERS:2:99}"

          # Truncate if needed
          [ ${#COMPOSER} -ge 44 ] && COMPOSER="${COMPOSER:0:43}…"
          [ ${#RECORDING} -ge 44 ] && RECORDING="${RECORDING:0:43}…"
          [ ${#DISTART} -ge 44 ] && DISTART="${DISTART:0:43}…"
          [ ${#PERFORMERS} -ge 44 ] && PERFORMERS=$(printf '%s' "$PERFORMERS" | awk '{print substr($0,1,43)}') && PERFORMERS="$PERFORMERS"$'\u2026'

          NUM='^[0-9]+$'
          if [[ -z $RECORDING_YEAR ]] || [[ ! $RECORDING_YEAR =~ $NUM ]]; then
            RECORDING_YEAR="?"
          fi

          # Output cleared lines and info
          for row in {13..23}; do tput cup $row 4; echo -en "                                             "; done
          tput cup 6 4; tput setaf $INFOTEXT; echo -en "$COMPOSER"
          tput cup 7 4; echo -en "$RECORDING"
          tput cup 8 4; echo -en "$DISTART"
          tput cup 9 4; echo -en "$PERFORMERS"
        
          tput cup 14 0; tput setaf $DRAWLINES; echo -en "├─────────────────────────────────────────────────┤"
          tput cup 16 4; tput setaf $MAINTEXT; echo -en "Days since last play: "; tput setaf $INFOTEXT; echo -en "$LASTPLAY"
          tput cup 17 4; tput setaf $MAINTEXT; echo -en "Recording Year: "; tput setaf $INFOTEXT; echo -en "$RECORDING_YEAR"
          tput cup 18 4; tput setaf $MAINTEXT; echo -en "Previous plays: "; tput setaf $INFOTEXT; echo -en "$PREVIOUS_PLAYS"
          tput cup 19 4; tput setaf $MAINTEXT; echo -en "ReplayGain Applied: "; tput setaf $INFOTEXT; echo -en "$RPGAIN"
          tput cup 20 4; tput setaf $MAINTEXT; echo -en "Ending at:"; tput cup 20 16; tput setaf $INFOTEXT; echo -en "$ENDINGAT"
          footer_line; tput cup 25 4; echo -e "$FOOTER"
        fi
      fi
    fi
  
    until [[ $option == q ]]; do
      tput cup 25 25; tput civis; read -n 1 -s -r option
      case $option in
         p|P ) FFMPEGCOUNT=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l); if [[ $FFMPEGCOUNT -eq 0 ]]; then source "$CONFDIR/bin/giomplay.sh"; gmenuoptions minig; fi;;
         f|F ) FFMPEGCOUNT=$(ps -ef | $GREPPROG "$FFNAME -stats_period 1" | $GREPPROG -v $GREPPROG | wc -l); if [[ $FFMPEGCOUNT -eq 0 ]]; then source "$CONFDIR/bin/giominifilter.sh"; gmenuoptions minig; fi;;
         1 ) source "$CONFDIR/bin/giominip.sh"; gmenuoptions minig;;
         2 ) source "$CONFDIR/bin/giopsink.sh"; gmenuoptions minig;;
         3 ) gmenuoptions minig;;
       a|A ) source "$CONFDIR/bin/giocontrol.sh" autostop; gmenuoptions minig;;
       t|T ) source "$CONFDIR/bin/giocontrol.sh" terminate; gmenuoptions minig;;
       s|S ) source "$CONFDIR/bin/giocontrol.sh" skip; gmenuoptions minig;;
       r|R ) source "$CONFDIR/bin/giocontrol.sh" repeat; gmenuoptions minig;;
   Q|q|X|x ) clear; tput cvvis; exit 0;;
      esac
    done
  fi
