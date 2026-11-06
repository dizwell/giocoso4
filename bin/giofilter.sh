#!/usr/bin/env bash
####################################################################
#
# giofilter: routine for displaying a form into which
# various music filters are prompted for and then setting
# appropriate variables to any supplied values
#
####################################################################
function parse_filter {
readarray -t musicfilter < "$CONFDIR/tmp/musicfilter.txt" 2>/dev/null

ARTLIST="${musicfilter[0]}"
ARTLISTNEG="${musicfilter[1]}"
ALBLIST="${musicfilter[2]}"
ALBLISTNEG="${musicfilter[3]}"
GENRELIST="${musicfilter[4]}"
GENRELISTNEG="${musicfilter[5]}"
COMLIST="${musicfilter[6]}"
COMLISTNEG="${musicfilter[7]}"
PERFLIST="${musicfilter[8]}"
PERFLISTNEG="${musicfilter[9]}"
RECDATE="${musicfilter[10]}"
MINDURATION="${musicfilter[11]}"
MAXDURATION="${musicfilter[12]}"
UNPLAYEDCOMP="${musicfilter[13]}"
UNPLAYEDWRKS="${musicfilter[14]}"
NOTRECENTPLY="${musicfilter[15]}"
NOTRECENTWRK="${musicfilter[16]}"

# If a specific composer was requested, handle it
# -----------------------------------------------------------------------------
if [[ ! -z $ARTLIST ]]; then
  ARTLIST=${ARTLIST^^}
  ARTLIST=$(echo "$ARTLIST" | $SEDPROG "s/'/\'\'/g"  2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)
  if [[ $ARTLISTNEG == "*" ]]; then
    ARTSQL="lower(COMPOSER) not like '%${ARTLIST,,}%'"
  else
    ARTSQL="lower(COMPOSER) like '%${ARTLIST,,}%'"
  fi
else
  ARTSQL="1=1"
fi

# If a specific composition was requested, handle it
# -----------------------------------------------------------------------------
if [[ ! -z $ALBLIST ]]; then
  ALBLIST=${ALBLIST^^}
  ALBLIST=$(echo "$ALBLIST" | $SEDPROG "s/'/\'\'/g"  2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)
  if [[ $ALBLISTNEG == "*" ]]; then
    ALBSQL="lower(COMPOSITION) not like '%${ALBLIST,,}%'"
  else
    ALBSQL="lower(COMPOSITION) like '%${ALBLIST,,}%'"
  fi
else
   ALBSQL="1=1"
fi

# If a specific genre was requested, handle it
# -----------------------------------------------------------------------------
if [[ ! -z $GENRELIST ]]; then
  GENRELIST=${GENRELIST^^}
  GENRELIST=$(echo "$GENRELIST" | $SEDPROG "s/'/\'\'/g"  2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)
  if [[ $GENRELISTNEG == "*" ]]; then
    GENRESQL="lower(GENRE) not like '%${GENRELIST,,}%'"
  else
    DISPLAYGENRELIST="$GENRELIST"
    GENRESQL="lower(GENRE) like '%${GENRELIST,,}%'"
  fi
else
  GENRESQL="1=1"
fi

# If a specific performer (as per the COMMENTS tag) was requested, handle it
# -----------------------------------------------------------------------------
if [[ ! -z $COMLIST ]]; then
  COMLIST=${COMLIST^^}
  COMLIST=$(echo "$COMLIST" | $SEDPROG "s/'/\'\'/g"  2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null )
  if [[ $COMLISTNEG == "*" ]]; then
    COMSQL="lower(COMMENT) not like '%${COMLIST,,}%'"
  else
    COMSQL="lower(COMMENT) like '%${COMLIST,,}%'"
  fi
else
   COMSQL="1=1"
fi

# If a specific distinguishing artist was requested, handle it
# -----------------------------------------------------------------------------
if [[ ! -z $PERFLIST ]]; then
  PERFLIST=${PERFLIST^^}
  PERFLIST=$(echo "$PERFLIST" | $SEDPROG "s/'/\'\'/g" 2>/dev/null | $SEDPROG "s/;//g" 2>/dev/null)
  if [[ $PERFLISTNEG == "*" ]]; then
    PERFSQL="lower(PERFORMER) not like '%${PERFLIST,,}%'"
  else
    PERFSQL="lower(PERFORMER) like '%${PERFLIST,,}%'"
  fi
else
   PERFSQL="1=1"
fi

# If a specific recording year was submitted, handle it
# -----------------------------------------------------------------------------
NUM='^[0-9]+$'
if [[ ! -z $RECDATE ]]; then
  if ! [[ $RECDATE =~ $NUM ]] ; then
    RECDATESQL="1=1"
  else
    RECDATESQL="composition like '%$RECDATE%'"
  fi
else
  RECDATESQL="1=1"
fi

# The under-played composers filter is complex. We first determine how long ago
# we played every composer. We then take a single average of that "days ago"
# value. Then we select recording from global_recordings by composers whose 
# personal 'days ago' value is larger than that global average, ensuring we
# only pick one (random) recording per qualified composer
# -----------------------------------------------------------------------------
if [[ ${UNPLAYEDCOMP,,} == y ]]; then
	UNDERPLAYEDSQL="exists (
	                  select 1
	                  from (
	                  select composer, composition, row_number() over (partition by composer order by rand()) as rn
	                  from global_recordings
	                  where composer in (
	                  select composer
	                  from underplayed_composers
	                  )
	                  ) as random_compositions
	                  where rn = 1
	                  and random_compositions.composer = global_recordings.composer
	                  and random_compositions.composition = global_recordings.composition
	                  )"
else
  UNDERPLAYEDSQL="1=1"
fi

# Unplayed recordings are easy to determine
# -----------------------------------------------------------------------------
if [[ ${UNPLAYEDWRKS,,} == y ]]; then
  UNPLAYEDWORKSQL="rechashvalue not in (select rechashvalue from global_plays)"
else
  UNPLAYEDWORKSQL="1=1"
fi

# If a min/max duration are NOT set, set them to defaults, otherwise
# just check they've been set to a valid numeric value
# -----------------------------------------------------------------------------
NUM='^[0-9]+$'
if [[ ! -z $MINDURATION ]]; then
  if ! [[ $MINDURATION =~ $NUM ]] ; then
    MINDURATION=0
  else
    MINDURATION=$((MINDURATION * 60))  # Convert MIN into a number of seconds, if it's not null but numeric
  fi
else
  MINDURATION=0
fi

if [[ ! -z $MAXDURATION ]]; then
  if ! [[ $MAXDURATION =~ $NUM ]] ; then
    MAXDURATION=$((525960 * 60))
  else
    MAXDURATION=$((MAXDURATION * 60))  # Convert MAX into a number of seconds, if it's not null but numeric
  fi
else
  MAXDURATION=$((525960 * 60))
fi

if [[ $MAXDURATION -lt $MINDURATION ]]; then  # If the two numbers are the wrong way round, reverse them back to being sensible
  NEWMIN=$MAXDURATION
  MAXDURATION=$MINDURATION;MAXDUR=$((MINDURATION * 60))
  MINDURATION=$NEWMIN;MINDUR=$((NEWMIN * 60))
fi

if [[ $MINDURATION -eq 0 && $MAXDURATION -eq 31557600 ]]; then        # Don't bother filtering for duration if no non-default durations have been supplied
  DURSTMT="1=1"
else
  DURSTMT="duration >= $MINDURATION and duration <= $MAXDURATION"
fi

SQLSTMT="select concat('"$FILEPREFIX"',filesuffix) as DIRNAME from global_recordings where"

# If the filter to play composers not played in the past X days is set, handle it	
if [[ -z $NOTRECENTPLY ]]; then
  NOTRECENTPLAYSTMT="1=1"
elif [[ $NOTRECENTPLY =~ $NUM ]]; then
  NOTRECENTPLAYSTMT="SELECT DIRNAME FROM (
    SELECT 
        CONCAT('"$FILEPREFIX"', filesuffix) AS DIRNAME,
        ROW_NUMBER() OVER (PARTITION BY composer ORDER BY RAND()) AS row_num
    FROM global_recordings 
    WHERE composer IN (
        SELECT composer 
        FROM global_plays 
        GROUP BY composer 
        HAVING MAX(playdate) < NOW() - INTERVAL $NOTRECENTPLY DAY
        )
	AND "$DURSTMT"
    ) AS ranked_recordings
      WHERE row_num = 1"
else 
  NOTRECENTPLAYSTMT="1=1"	  
fi

# If the filter to play recordings not played in the past number of days, handle that now
if [[ -z $NOTRECENTWRK ]]; then
  NOTRECENTWORKSTMT="1=1"
elif [[ $NOTRECENTWRK =~ $NUM ]]; then
  NOTRECENTWORKSTMT="select CONCAT('"$FILEPREFIX"', filesuffix) AS DIRNAME
  from global_recordings gr
  join (
    select composer, composition
    from global_plays
    group by composer, composition
    having datediff(curdate(), date(max(playdate))) >= $NOTRECENTWRK
  ) gp on gp.composer = gr.composer
  and gp.composition = gr.composition
  where "$DURSTMT""
else
  NOTRECENTWORKSTMT="1=1"
fi

# And now we can construct a SQLSTMT. Note that if Composers not played recently is selected, that takes precedence over everything else
# If Works not played recently is selected, that takes precedence.
# Only if neither are set do we then do the other filters
if [[ ! $NOTRECENTPLAYSTMT == 1=1 ]]; then 
  SQLSTMT="$NOTRECENTPLAYSTMT"
elif [[ ! $NOTRECENTWORKSTMT == 1=1 ]]; then
  SQLSTMT="$NOTRECENTWORKSTMT"	
else
  if [[ ! $ARTSQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $ARTSQL"; fi
  if [[ ! $ALBSQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $ALBSQL"; fi
  if [[ ! $COMSQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $COMSQL"; fi
  if [[ ! $PERFSQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $PERFSQL"; fi
  if [[ ! $GENRESQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $GENRESQL"; fi
  if [[ ! $RECDATESQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $RECDATESQL"; fi
  if [[ ! $UNDERPLAYEDSQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $UNDERPLAYEDSQL"; fi
  if [[ ! $UNPLAYEDWORKSQL == 1=1 ]]; then SQLSTMT="$SQLSTMT and $UNPLAYEDWORKSQL"; fi
  if [[ ! $DURSTMT == 1=1 ]]; then SQLSTMT="$SQLSTMT and $DURSTMT"; fi
fi

SQLSTMT="$SQLSTMT order by rand();"
SQLSTMT="${SQLSTMT/where and/where}"        # Needed to deal with syntactical difficulties when partial combinations of filters are supplied
SQLSTMT="${SQLSTMT/where  and/where}"       # Needed to deal with syntactical difficulties when partial combinations of filters are supplied
DIRBASE=$("${PROCONN[@]}" -N -e "$SQLSTMT" 2>/dev/null)

# The results of the query might contain many candidate folders. We should check all of them exist and contain FLACs before
# creating a results set that can be played. If folders are non-existent or don't contain FLACs, don't add them to VALIDDIRS.
# Otherwise, VALIDDIRS becomes our candidate playlist
unset VALIDDIRS; FOLDERCOUNT=1; MAXFOLDER=$(echo "$DIRBASE" | wc -l)
while IFS= read -r FOLDER; do
  tput civis; tput cup 25 4; echo -e "Checking candidate folders... $FOLDERCOUNT / $MAXFOLDER"
  if [[ -z $FOLDER ]]; then
    :
  elif [[ ! -d $FOLDER ]]; then
    :
  else
    # There is a result, it exists on disk... does it contain flacs?
    if ! compgen -G "$FOLDER/*.flac" >/dev/null; then
      :
    else
      VALIDDIRS="$VALIDDIRS"$'\n'"$FOLDER"
    fi
  fi
((FOLDERCOUNT++))
done <<< "$DIRBASE"

# Offer to save the results in a Stored Query, provided there is more than 1 piece to play
if [[ $( echo "$VALIDDIRS" | wc -l) -gt 2 && $USE_STORED -eq 0 ]]; then
  QUERYNAME=" Query name here (Ctrl+U to clear) "
  dialog --yesno "Do you want to save this query as a Stored Query for future use?" 10 30
  dialog_status=$?
  if [[ $dialog_status -eq 0 ]]; then
    tput cvvis
	save_query=1
	while true; do
	  storedquery_name=$(dialog --inputbox "Enter a unique name for this Stored Query" 15 60 "$QUERYNAME" 3>&1 1>&2 2>&3 3>&-)
	  DIALOGSTATUS=$?
	  if [[ $DIALOGSTATUS -ne 0 ]]; then save_query=0; break; fi
	  
	  storedquery_name="${storedquery_name// /_}"									# Turn spaces into underscores
	  storedquery_name="${storedquery_name//\"/}"									# Removes double quotes
	  storedquery_name="${storedquery_name//\'/\'\'}"								# Doubles up (i.e., escapes) single quotes
	  storedquery_name=$(printf '%s' "$storedquery_name" | tr -cd '[:alnum:] _.-')	# Removes everything except letters, numbers, spaces, underscores, fullstops and hyphens

	  if [[ -z $storedquery_name ]]; then
	    continue
	  fi

	  DUPLICATE=$("${PROCONN[@]}" -N -B -e "select count(*) from stored_queries where query_name='$storedquery_name';")

	  if [[ $DUPLICATE -eq 0 ]]; then
	    break
	  fi

	  dialog --title " Duplicate Query Name Detected! " --msgbox "\nA Stored Query called '$storedquery_name' already exists.\n\nPlease choose another name." 10 50
	  QUERYNAME=""
	done
	
	if [[ save_query -eq 1 ]]; then
	  storedquery_text="$SQLSTMT"
  	  placeholdertext="concat('$FILEPREFIX',filesuffix)"
  	  storedquery_text="${storedquery_text//"$placeholdertext"/xxQQzQZ}"             # Replaces fixed path to files with placeholder	
	  storedquery_text="${storedquery_text//\'/\'\'}"									# Doubles up (i.e., escapes) single quotes
	
	  INSERTSQL="insert into stored_queries values ('$storedquery_name','$storedquery_text')"
	  "${PROCONN[@]}" -N -e "$INSERTSQL"
    fi
  fi
fi
}

rm -f "$CONFDIR/txt/terminate.txt"
if ! [[ -d $CONFDIR/tmp ]]; then mkdir -p "$CONFDIR/tmp" 2>/dev/null; fi
FILENAME="$CONFDIR/tmp/musicfilter.txt"

if ! [[ -f $FILENAME ]]; then
  touch "$FILENAME"
else
  rm -f "$FILENAME"
  touch "$FILENAME"	
fi

dialog --backtitle "Giocoso Music Selection by Filter" --title " Please enter your selection criteria below " --form "" 20 90 14 \
"Composer Name    " 1 1  "" 1 30 35 0 \
"±          " 1 72 ""  1 74 2 0 \
"Composition Name " 2 1  ""     2 30 35 0 \
"±          " 2 72 ""      2 74 2 0 \
"Genre            " 3 1  ""    3 30 35 0 \
"±          " 3 72 ""     3 74 2 0 \
"Performer        " 4 1  ""     4 30 35 0 \
"±           " 4 72 ""      4 74 2 0 \
"Distinguishing Artist        " 5 1  ""     5 30 35 0 \
"±           " 5 72 ""      5 74 2 0 \
"Recording Year        " 6 1  ""     6 30 5 0 \
"Minimum Duration (minutes)" 8 1 "" 8 30 10 0 \
"Maximum Duration (minutes)" 9 1 "" 9 30 10 0 \
"Under-played Composers (Y/N)" 10 1 "" 10 30 2 1 \
"Unplayed Recordings (Y/N)" 11 1 "" 11 30 2 1 \
"Composers not played in past number of days" 13 1 "" 13 57 8 5 \
"Recordings not played in past number of days" 14 1 "" 14 57 8 5 \
2>"$CONFDIR/tmp/musicfilter.txt"
DIALOGSTATUS=$?

FILTERCANCELLED=0
if [[ $DIALOGSTATUS -eq 1 || $DIALOGSTATUS -eq 255 ]]; then
  FILTERCANCELLED=1	# Status 1 means they took the 'Cancel' option; 255 is they pressed 'ESC'. Tell the caller to return to the main menu without playing anything
else
  parse_filter	
fi

rm -f "$CONFDIR/tmp/musicfilter.txt" 2>/dev/null
rm -f "$CONFDIR/txt/searchfilter.txt" 2>/dev/null

if [[ $FILTERCANCELLED -eq 0 ]]; then
  echo "$VALIDDIRS" > "$CONFDIR/txt/searchfilter.txt"
  sleep .1
  $SEDPROG -i '/^[[:space:]]*$/d' "$CONFDIR/txt/searchfilter.txt" 2>/dev/null      # Remove blank line from top of file list, should there be one
  $SEDPROG -i '/concat(/d' "$CONFDIR/txt/searchfilter.txt" 2>/dev/null             # Remove query from top of file list, should it get into there
  sleep .2
fi