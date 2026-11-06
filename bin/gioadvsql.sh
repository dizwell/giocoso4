#!/usr/bin/env bash
####################################################################
#
# gioadvsql: routine for displaying a form into which
# a SQL statement can be typed for music-playing purposes.
# Submitted SQL is cleansed of 'delete', 'drop', 'create' and 
#'update' keywords along with semi-colons.
#
####################################################################
STOREDQUERIES=0

tput cvvis
if ! [[ -d $CONFDIR/tmp ]]; then mkdir -p "$CONFDIR/tmp" 2>/dev/null; fi
FILENAME="$CONFDIR/tmp/sqlfilter.txt"

if ! [[ -f $FILENAME ]]; then
  touch "$FILENAME"
else
  rm -f "$FILENAME"
  touch "$FILENAME"
fi

function new_query {
USE_STORED=0
dialog --backtitle "Giocoso Advanced SQL Selection" --title "  Type a WHERE clause below " --editbox "$FILENAME" 12 90 2>"$FILENAME"
exitStatus=$?
if [[ $exitStatus -eq 0 ]]; then
  $SEDPROG -i ':a;N;$!ba;s/\n/ /g' "$FILENAME" 2>/dev/null     # Turns a multi-line query into a single line of text, which is needed to parse correctly.
  readarray -t sqlfilter < "$CONFDIR/tmp/sqlfilter.txt" 2>/dev/null
  SQLTXT="${sqlfilter[0]}"
  shopt -s nocasematch # makes the string search case-insensitive
  SQLTXT="${SQLTXT//delete/}"
  SQLTXT="${SQLTXT//update/}"
  SQLTXT="${SQLTXT//drop/}"
  SQLTXT="${SQLTXT//create/}"
  SQLTXT="${SQLTXT//;/}"
  shopt -u nocasematch
  echo "$SQLTXT" > "$CONFDIR/txt/advsqltext.txt"
fi
}

function fetch_stored_query {
QUERYLIST=()	
while IFS= read -r QUERYNAME; do
  QUERYLIST+=("$QUERYNAME" "$QUERYNAME" off)
done < <("${PROCONN[@]}" -N -B -e "select query_name from stored_queries order by query_name")

CHOSENQUERY=$(dialog --no-tags --backtitle "Advanced SQL Selection of Music" --title " Select a Stored Query " --radiolist "\nPlease select the query to use:\n" 15 90 0 "${QUERYLIST[@]}" 3>&1 1>&2 2>&3 3>&-)	

exitStatus=$?
if [[ $exitStatus -eq 0 ]]; then
  USE_STORED=1  
  QUERY_NAME="$CHOSENQUERY"
  QUERY_NAME=$(echo "$QUERY_NAME" | $SEDPROG "s/'/\'\'/g" 2>/dev/null)
  QRYTEXT=$("${PROCONN[@]}" -N -B -e "select query_text from stored_queries where query_name='$QUERY_NAME';" 2>/dev/null)
  replacement="concat('$FILEPREFIX',filesuffix)"
  QRYTEXT="${QRYTEXT//xxQQzQZ/$replacement}"		# Replaces placeholder text with variable and column name that identifies FLACs' locations for the specific machine running the query
else
  new_query	
fi
}

function store_query {
if [[ $( echo "$VALIDDIRS" | wc -l) -gt 1 && $USE_STORED -eq 0 ]]; then
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

	  if [[ $DUPLICATE -eq 0 ]]; then break; fi

	  dialog --title " Duplicate Query Name Detected! " --msgbox "\nA Stored Query called '$storedquery_name' already exists.\n\nPlease choose another name." 10 50
	  QUERYNAME=""
	done
	
	if [[ save_query -eq 1 ]]; then
	  # need to remove the hard-coded file path to make the query portable.	
	  storedquery_text="$SQLSTMT"
	  placeholdertext="concat('$FILEPREFIX',filesuffix)"
	  storedquery_text="${storedquery_text//"$placeholdertext"/xxQQzQZ}"             # Replaces fixed path to files with placeholder
	  storedquery_text="${storedquery_text//\'/\'\'}"								 # Doubles up (i.e., escapes) single quotes
	  INSERTSQL="insert into stored_queries values ('$storedquery_name','$storedquery_text')"
	  "${PROCONN[@]}" -N -e "$INSERTSQL"
    fi
  fi
fi
}

function assess_folders {
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
}

function main {
unset QRYTEXT
unset SQLTXT
SQLCANCELLED=0
rm -f "$CONFDIR/tmp/musicfilter.txt" 2>/dev/null
rm -f "$CONFDIR/txt/searchfilter.txt" 2>/dev/null
rm -f "$CONFDIR/txt/sqlfilter.txt" 2>/dev/null
rm -f "$CONFDIR/txt/advsqltext.txt"
	
# First check if there are any stored queries and display them if so
STOREDQUERIES=$("${PROCONN[@]}" -N -B -e "select count(*) from stored_queries;")
if [[ $STOREDQUERIES -eq 0 ]]; then
  new_query
else
  fetch_stored_query
fi

# Cancelled at every stage? Then there is nothing to run: tell play_sql to return to the menu quietly
if [[ -z $SQLTXT && -z $QRYTEXT ]]; then SQLCANCELLED=1; return; fi

# If we've used a stored query, QRYTEXT won't need cleaning. 
# If we've done a new query, SQLTXT will need some massaging though
if [[ ! -z $SQLTXT ]]; then
  FIRSTWORD=${SQLTXT%% *}; FIRSTWORD=${FIRSTWORD^^}
  if [[ $FIRSTWORD != WHERE ]]; then SQLTXT="where $SQLTXT"; fi
  SQLSTMT="select concat('"$FILEPREFIX"',filesuffix) from global_recordings $SQLTXT order by rand()"
  DIRBASE=$("${PROCONN[@]}" -N -B -e "$SQLSTMT" 2>/dev/null)
else
  DIRBASE=$("${PROCONN[@]}" -N -B -e "$QRYTEXT" 2>/dev/null)
fi

# The results of the query might contain many candidate folders. We should check all of them exist and contain FLACs before
# creating a results set that can be played. If folders are non-existent or don't contain FLACs, don't add them to VALIDDIRS.
# Otherwise, VALIDDIRS becomes our candidate playlist
assess_folders

# Offer to save the results in a Stored Query, provided there is more than 1 piece to play
store_query

tput cvvis
rm -f "$CONFDIR/tmp/musicfilter.txt" 2>/dev/null
rm -f "$CONFDIR/txt/searchfilter.txt" 2>/dev/null
rm -f "$CONFDIR/txt/advsqltext.txt" 2>/dev/null

echo "$VALIDDIRS" > "$CONFDIR/txt/searchfilter.txt"
$SEDPROG -i '/^[[:space:]]*$/d' "$CONFDIR/txt/searchfilter.txt" 2>/dev/null      # Remove blank line from top of file list, should there be one
$SEDPROG -i '/concat(/d' "$CONFDIR/txt/searchfilter.txt" 2>/dev/null            # Remove query from top of file list, should it get into there
sleep .1
}

main






