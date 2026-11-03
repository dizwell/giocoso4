#!/usr/bin/env bash
####################################################################
#
# giodefsrch: routine for performing standard, default search. Note
# that there are no configured default min/max duration or unplayed 
# works or underplayed composers parameters in Giocoso 4. Therefore,
# default search simply selects on the basis of timebar and explicit
# excluaion.
#
####################################################################
# Ensure all variables are read and set, every time a query is performed
source "$CONFDIR/bin/gioparse.sh"

rm -f "$CONFDIR/txt/searchfilter.txt"; touch "$CONFDIR/txt/searchfilter.txt"
rm -f "$CONFDIR/txt/terminate.txt"

if [[ $DIRECT_PLAY -eq 0 ]]; then
  tput cup 25 1; echo -e "                                                            "
else
  tput cup 25 1; echo -e "                              "
fi

# -----------------------------------------------------------------------------
# First, catch your composer. Candidate composers are those who:
# a) Are NOT timebarred or those who, despite being timebarred, have been exempted
# b) Are NOT in the excludes file.
# -----------------------------------------------------------------------------

# A: Construct a Time Barred Composer statement ($TIMEBARCOMP)  [composer NOT in ...]
# The SQL produces a list of composers who are time-barred (so must be excluded from the candidate pool), but
# it automatically removes from the exclusion list any composer selected in the global_exempts table.
# ===============================================================================================================
TIMEBAR_ABS=$((TIMEBAR < 0 ? -TIMEBAR : TIMEBAR))		# Turns "-6" from the config file into just "6", for example  
TIMEBARCOMP=$("${PROCONN[@]}" -N -B -e "select distinct gp.composer from global_plays gp
  	                                    where gp.playdate >= now() - interval $TIMEBAR_ABS hour
  	                                    and not exists (select 1 from global_exempts ge where ge.composer = gp.composer and ge.selection = 'yes');" | awk '{printf "QQqZ%sQQqZ,", $0}' | $SEDPROG 's/,$//' 2>/dev/null)
	  
if [[ -z $TIMEBARCOMP ]]; then 
  TIMEBARCOMP="QQqZ1-1QQqZ"
fi
TIMEBARCOMP="(${TIMEBARCOMP//\'/\'\'})"
TIMEBARCOMP="${TIMEBARCOMP//QQqZ/\'}"

# Remove all literal '', sequences (empty entries) that may have been created
TIMEBARCOMP="${TIMEBARCOMP//\'\'\,/}"
TIMEBARCOMP="${TIMEBARCOMP//,,/,}"
if [[ $TIMEBARCOMP == "()" ]]; then 
  TIMEBARCOMP="('QQqZ')"
fi	
  
# B: Construct an Excludes filter ($EXCLUDESTRING) [composer not in...]
# ==============================================================================================================
EXCLUDESTRING=$("${PROCONN[@]}" -N -B -e "select composer from global_excludes where selection='yes';" | awk '{printf "QQqZ%sQQqZ,", $0}' | $SEDPROG 's/,$//' 2>/dev/null)
if [[ -z $EXCLUDESTRING ]]; then
  EXCLUDESTRING="''"
fi
EXCLUDESTRING=$EXCLUDESTRING')'           	# Closes the string off with a closing bracket
EXCLUDESTRING='('$EXCLUDESTRING           	# Adds an opening bracket to the start of the string
EXCLUDESTRING=${EXCLUDESTRING//\'/\'\'}
EXCLUDESTRING="${EXCLUDESTRING//QQqZ/\'}"

if [[ $EXCLUDESTRING == "()" ]]; then 
  EXCLUDESTRING="(1=1)"
fi

# ===============================================================================================================
# All Sub-Components of the Composer Selection Filter have now been determined:
# Time to create a SQL statement to construct a pool of candidate composers. 
# Excludes are absolute: if you're in global_excludes you are not to be allowed here
# The Timebarcomp
# ===============================================================================================================
SQLSTMT="select distinct composer from global_recordings where composer not in $EXCLUDESTRING and composer not in $TIMEBARCOMP order by rand()"

# ===============================================================================================================
# Now execute that query and process the results, line by line, to create an array of Composers who ARE valid
# candidates for the next music selection.
# ===============================================================================================================
SEARCHARTIST=""
while IFS= read -r COMPOSER; do
  [[ -z "$COMPOSER" ]] && continue
  COMPOSER_ESC=${COMPOSER//\'/\'\'}       # double apostrophes
  SEARCHARTIST+="'$COMPOSER_ESC',"
done < <("${PROCONN[@]}" -N -B -e "$SQLSTMT" 2>/dev/null)
      
# Remove trailing comma and wrap in parentheses
SEARCHARTIST="(${SEARCHARTIST%,})"

# ================================================================================================================================== #
# That's the candidate pool of composers prepared. We now need to pass those candidates over to the music selection
# process, which evaluates particular recordings for duration, played status and so on
# ================================================================================================================================== #
SQLSTMT=$(source "$CONFDIR/bin/giosql.sh")  # This call constructs a select of recordings that meet selection criteria	
	
# Now execute whatever prepared statement we've arrived at. This returns the directory whose contents we will play
"${PROCONN[@]}" -N -B -e "$SQLSTMT" 2>/dev/null > "$CONFDIR/tmp/defaultsearchresults.txt"
	  
# If there any results of the query at all, it might contain many candidate folders. We should check all of them exist and contain FLACs before
# creating a results set that can be played. If folders are non-existent or don't contain FLACs, don't add them to VALIDDIRS.
# Otherwise, VALIDDIRS becomes our candidate playlist
unset VALIDDIRS; FOLDERCOUNT=1; MAXFOLDER=$(( $(cat "$CONFDIR/tmp/defaultsearchresults.txt" | wc -l) ))
echo > "$CONFDIR/tmp/folders-to-be-played.txt"
while IFS= read -r FOLDER; do
  FOLDER="$FILEPREFIX$FOLDER"
  echo "$FOLDER" >> "$CONFDIR/tmp/folders-to-be-played.txt"
  tput civis; tput cup 25 4; echo -e "Checking candidate folders... $FOLDERCOUNT / $MAXFOLDER"

  if [[ ! -d $FOLDER ]]; then
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
done < "$CONFDIR/tmp/defaultsearchresults.txt"
	  
sleep .1
echo "$VALIDDIRS" > "$CONFDIR/txt/searchfilter.txt"
$SEDPROG -i '/^[[:space:]]*$/d' "$CONFDIR/txt/searchfilter.txt" 2>/dev/null     # Remove blank line from top of file list, should there be one
$SEDPROG -i '/concat(/d' "$CONFDIR/txt/searchfilter.txt" 2>/dev/null            # Remove query from top of file list, should it get into there
sleep .2