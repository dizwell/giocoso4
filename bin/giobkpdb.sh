#!/usr/bin/env bash
####################################################################
#
# A function to backup and restore a MariaDB database (at minimum, the
# global_plays table contained within a Giocoso database).
#
# Script will prompt for the source and destination, so can be used 
# to do Version 4 backups, as well as to do a Version 3 to 4 
# migration.
#
####################################################################
MOVEOK=0 GOODSOURCE=0 GOODDEST=0 IMPORTSUCCESS=0
function prompt_source {
  while true; do
	RESULT=$(dialog --backtitle "Giocoso Database Backup & Restore" --title " Connection to SOURCE database " --form "\nPlease provide the connection credentials for connecting to the SOURCE database: (Ctrl+U clears default entries)\n" 15 70 5 \
	  "Source Host:"      1 1 "$DEFAULTIP" 1 30 30 0 \
	  "Port:"      2 1 "3306" 2 30 30 0 \
	  "Source Database:"  3 1 "$DEFAULTSRCDB" 3 30 30 0 \
	  "Username:"  4 1 "$DEFAULTSRCDB" 4 30 30 0 \
	  "Password:" 5 1 "$DEFAULTSRCDB" 5 30 30 0 \
	  2>&1 >/dev/tty)
		  
    if [[ $? -ne 0 ]]; then
	  return 1
	fi

	SOURCEHOST=$(echo "$RESULT" | $SEDPROG -n '1p' 2>/dev/null | $SEDPROG -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null)
	SOURCEPORT=$(echo "$RESULT" | $SEDPROG -n '2p' 2>/dev/null | $SEDPROG -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null)
	SOURCEDB=$(echo "$RESULT" | $SEDPROG -n '3p' 2>/dev/null | $SEDPROG -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null)
	SOURCEUSR=$(echo "$RESULT" | $SEDPROG -n '4p' 2>/dev/null | $SEDPROG -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null)
	SOURCEPWD=$(echo "$RESULT" | $SEDPROG -n '5p' 2>/dev/null | $SEDPROG -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null)
	
	if mariadb -h "$SOURCEHOST" -P "$SOURCEPORT" -u "$SOURCEUSR" -p"$SOURCEPWD" "$SOURCEDB" -e "SELECT 1" >/dev/null 2>&1; then
	  GOODSOURCE=1
	  break
	else
	  dialog --backtitle "Giocoso Database Backup & Restore" --title " Connection Error " --msgbox "\nUnable to connect to the SOURCE database.\n\nPlease check the connection details and try again.\n" 9 60
	fi
  done
}

function prompt_dest {
  while true; do
	RESULT=$(dialog --backtitle "Giocoso Database Backup & Restore" --title " Connection to DESTINATION database " --form "\nPlease provide the connection credentials for connecting to the DESTINATION database:\n\n" 15 70 5 \
	  "Destination Host:"      1 1 "$DEFAULTIP" 1 30 30 0 \
	  "Port:"      2 1 "3306" 2 30 30 0 \
	  "Destination Database:"  3 1 "$DEFAULTDSTDB" 3 30 30 0 \
	  "Username:"  4 1 "$DEFAULTDSTDB" 4 30 30 0 \
	  "Password:" 5 1 "$DEFAULTDSTDB" 5 30 30 0 \
	  2>&1 >/dev/tty)

    if [[ $? -ne 0 ]]; then
	  return 1
	fi
	
    DESTHOST=$(echo "$RESULT" | $SEDPROG -n '1p' 2>/dev/null | $SEDPROG -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null)
    DESTPORT=$(echo "$RESULT" | $SEDPROG -n '2p' 2>/dev/null | $SEDPROG -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null)
    DESTDB=$(echo "$RESULT" | $SEDPROG -n '3p' 2>/dev/null | $SEDPROG -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null)
    DESTUSR=$(echo "$RESULT" | $SEDPROG -n '4p' 2>/dev/null | $SEDPROG -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null)
    DESTPWD=$(echo "$RESULT" | $SEDPROG -n '5p' 2>/dev/null | $SEDPROG -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null)
	
	if mariadb -h "$DESTHOST" -P "$DESTPORT" -u "$DESTUSR" -p"$DESTPWD" "$DESTDB" -e "SELECT 1" >/dev/null 2>&1; then
	  GOODDEST=1
	  break
	else
	  dialog --backtitle "Giocoso Database Backup & Restore" --title " Connection Error " --msgbox "\nUnable to connect to the DESTINATION database.\n\nPlease check the connection details and try again.\n" 9 60
	fi
  done
}

function move_plays {
TMPFILE=$(mktemp)

# Export in mariadb's own batch format (tab between columns; tab, newline and backslash inside a value are escaped) and
# load it with LOAD DATA's default format, which reverses that escaping, so no character in a value can upset the layout.
# Batch format prints a NULL as the word NULL, so the load turns that word back into a real NULL (a TIME column, for one, would not accept the text).
mariadb -h "$SOURCEHOST" -P "$SOURCEPORT" -u "$SOURCEUSR" -p"$SOURCEPWD" "$SOURCEDB" \
  --default-character-set=utf8mb4 --batch --skip-column-names \
  -e "SELECT playhashvalue, rechashvalue, playdate, foldername, composer, composition, genre, performer, duration, devicename, os_type FROM global_plays" \
  > "$TMPFILE" 2>/dev/null
EXPORTRC=$?

ROWS=$(wc -l < "$TMPFILE" | tr -d ' ')
if [[ $EXPORTRC -ne 0 ]]; then
  MOVE_PLAYS="FAILED"
elif [[ $ROWS -eq 0 ]]; then
  MOVE_PLAYS="none to copy"
else
  mariadb -h "$DESTHOST" -P "$DESTPORT" -u "$DESTUSR" -p"$DESTPWD" "$DESTDB" \
    --default-character-set=utf8mb4 --local-infile=1 \
    -e "LOAD DATA LOCAL INFILE '$TMPFILE' IGNORE INTO TABLE global_plays (playhashvalue, @rechashvalue, @playdate, @foldername, @composer, @composition, @genre, @performer, @duration, @devicename, @os_type) SET rechashvalue=NULLIF(@rechashvalue,'NULL'), playdate=NULLIF(@playdate,'NULL'), foldername=NULLIF(@foldername,'NULL'), composer=NULLIF(@composer,'NULL'), composition=NULLIF(@composition,'NULL'), genre=NULLIF(@genre,'NULL'), performer=NULLIF(@performer,'NULL'), duration=NULLIF(@duration,'NULL'), devicename=NULLIF(@devicename,'NULL'), os_type=NULLIF(@os_type,'NULL')" 2>/dev/null
  if [[ $? -eq 0 ]]; then MOVE_PLAYS="$ROWS copied"; else MOVE_PLAYS="FAILED"; fi
fi
rm -f "$TMPFILE"
}

function move_notes {
TMPFILE=$(mktemp)

# Export in mariadb's own batch format (tab between columns; tab, newline and backslash inside a value are escaped)
# and load it with LOAD DATA's default format, which reverses exactly that escaping. Any note text survives intact, | included.
mariadb -h "$SOURCEHOST" -P "$SOURCEPORT" -u "$SOURCEUSR" -p"$SOURCEPWD" "$SOURCEDB" \
  --default-character-set=utf8mb4 --batch --skip-column-names \
  -e "SELECT rechashvalue, notes FROM global_notes WHERE notes IS NOT NULL AND notes <> ''" \
  > "$TMPFILE" 2>/dev/null
EXPORTRC=$?

ROWS=$(wc -l < "$TMPFILE" | tr -d ' ')
if [[ $EXPORTRC -ne 0 ]]; then
  MOVE_NOTES="FAILED"
elif [[ $ROWS -eq 0 ]]; then
  MOVE_NOTES="none to copy"
else
  mariadb -h "$DESTHOST" -P "$DESTPORT" -u "$DESTUSR" -p"$DESTPWD" "$DESTDB" \
    --default-character-set=utf8mb4 --local-infile=1 \
    -e "LOAD DATA LOCAL INFILE '$TMPFILE' IGNORE INTO TABLE global_notes (rechashvalue, notes)" 2>/dev/null
  if [[ $? -eq 0 ]]; then MOVE_NOTES="$ROWS copied"; else MOVE_NOTES="FAILED"; fi
fi
rm -f "$TMPFILE"
}

function move_sql {
TMPFILE=$(mktemp)

# Same format as move_plays and move_notes: a | (or a newline) inside a stored query can no longer break the load
mariadb -h "$SOURCEHOST" -P "$SOURCEPORT" -u "$SOURCEUSR" -p"$SOURCEPWD" "$SOURCEDB" \
  --default-character-set=utf8mb4 --batch --skip-column-names \
  -e "SELECT query_name, query_text FROM stored_queries" \
  > "$TMPFILE" 2>/dev/null
EXPORTRC=$?

ROWS=$(wc -l < "$TMPFILE" | tr -d ' ')
if [[ $EXPORTRC -ne 0 ]]; then
  MOVE_SQL="FAILED"
elif [[ $ROWS -eq 0 ]]; then
  MOVE_SQL="none to copy"
else
  mariadb -h "$DESTHOST" -P "$DESTPORT" -u "$DESTUSR" -p"$DESTPWD" "$DESTDB" \
    --default-character-set=utf8mb4 --local-infile=1 \
    -e "LOAD DATA LOCAL INFILE '$TMPFILE' IGNORE INTO TABLE stored_queries (query_name, @query_text) SET query_text=NULLIF(@query_text,'NULL')" 2>/dev/null
  if [[ $? -eq 0 ]]; then MOVE_SQL="$ROWS copied"; else MOVE_SQL="FAILED"; fi
fi
rm -f "$TMPFILE"
}

function move_phonemes {
TMPFILE=$(mktemp)

# Only rows carrying a real pronunciation (a voice or a phoneme) are worth moving: blank rows are placeholders that the
# recordings trigger creates for every composition. The merge differs from the other moves, because a blank row already in the
# destination must not shield the source's real value. So: load into a temporary table, fill in destination rows that are blank,
# and add rows the destination lacks. A destination row that already has a real value is never touched.
# A Giocoso 3 source has no user_phonemes table: the export fails quietly, the file is empty, and nothing happens.
mariadb -h "$SOURCEHOST" -P "$SOURCEPORT" -u "$SOURCEUSR" -p"$SOURCEPWD" "$SOURCEDB" \
  --default-character-set=utf8mb4 --batch --skip-column-names \
  -e "SELECT phrase, voice, phoneme FROM user_phonemes WHERE voice IS NOT NULL OR phoneme IS NOT NULL" \
  > "$TMPFILE" 2>/dev/null
EXPORTRC=$?

ROWS=$(wc -l < "$TMPFILE" | tr -d ' ')
# A Giocoso 3 source has no user_phonemes table, so a failed export here means nothing to copy, not a failure
if [[ $ROWS -eq 0 ]]; then
  MOVE_PHON="none to copy"
else
  mariadb -h "$DESTHOST" -P "$DESTPORT" -u "$DESTUSR" -p"$DESTPWD" "$DESTDB" \
    --default-character-set=utf8mb4 --local-infile=1 \
    -e "CREATE TEMPORARY TABLE moving_phonemes LIKE user_phonemes;
        LOAD DATA LOCAL INFILE '$TMPFILE' INTO TABLE moving_phonemes (phrase, @voice, @phoneme) SET voice=NULLIF(@voice,'NULL'), phoneme=NULLIF(@phoneme,'NULL');
        UPDATE user_phonemes u JOIN moving_phonemes m ON u.phrase = m.phrase SET u.voice = m.voice, u.phoneme = m.phoneme WHERE u.voice IS NULL AND u.phoneme IS NULL;
        INSERT IGNORE INTO user_phonemes (phrase, voice, phoneme) SELECT phrase, voice, phoneme FROM moving_phonemes;" 2>/dev/null
  if [[ $? -eq 0 ]]; then MOVE_PHON="$ROWS copied"; else MOVE_PHON="FAILED"; fi
fi
rm -f "$TMPFILE"
}

function dump_db {
BACKUPSUCCESS="NO"	
if [[ -z $MARIADBDUMP ]]; then BACKUPSUCCESS="NODUMP"; return; fi     # No dump program found: say so, and don't create an empty backup file
# Each backup gets its own name, to the second, so no backup ever overwrites another. The dump goes to a temporary
# .part file first, which only becomes a .sql backup if the dump succeeds: a failed dump is deleted, so the Restore
# list only ever shows complete backups.
BACKUPFILE="$BACKUP_DIR/giocoso4-$(date +%Y%m%d-%H%M%S).sql"
if "$MARIADBDUMP" -h "$SOURCEHOST" -P "$SOURCEPORT" -u "$SOURCEUSR" -p"$SOURCEPWD" "$SOURCEDB" > "$BACKUPFILE.part" 2>/dev/null && mv -f "$BACKUPFILE.part" "$BACKUPFILE"; then
  BACKUPSUCCESS="YES"
  # Keep only the ten newest backups of this kind (the names sort oldest to newest). Older-style one-a-day backups
  # (giocoso4-YYYYMMDD.sql) are left alone.
  mapfile -t OLDBKPS < <(printf '%s\n' "$BACKUP_DIR"/giocoso4-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].sql | LC_ALL=C sort)
  if [[ ${#OLDBKPS[@]} -gt 10 && -f ${OLDBKPS[0]} ]]; then
    rm -f "${OLDBKPS[@]:0:${#OLDBKPS[@]}-10}"
  fi
else
  rm -f "$BACKUPFILE.part"
  BACKUPSUCCESS="NO"
fi
}

function restore_db {
local IFS=$'\n'
DBLIST=()
for FILE in "$BACKUP_DIR"/*.sql; do
  [[ -f "$FILE" ]] && DBLIST+=("$(basename "$FILE")" "$(basename "$FILE")" off)
done
if [[ ${#DBLIST[@]} -eq 0 ]]; then                    # An empty list can't be drawn: say why there's nothing to choose
  dialog --backtitle "Giocoso Database Restore" --title " No Backups Found " --msgbox "\nNo database backups were found in your configured backup folder, $BACKUP_DIR.\n\nPress OK to return to the main menu." 10 70
  return 1
fi
RESULT=$(dialog --no-tags --backtitle "Giocoso Database Backup & Restore" --title " Select Database Backup " --radiolist "\nPlease select the backup you wish to restore:\n" 15 80 8 "${DBLIST[@]}" 2>&1 >/dev/tty)

if [[ $? -eq 0 && -n $RESULT ]]; then
  RESTOREFILE="$BACKUP_DIR/$RESULT"
  # A restore replaces the database's contents: say exactly what is about to happen, and default to No
  if ! dialog --backtitle "Giocoso Database Restore" --title " Confirm Restore " --no-mouse --defaultno --yesno "\nRestoring this backup:\n\n    $RESULT\n\nwill replace everything in the '$DESTDB' database on $DESTHOST with the backup's contents. Anything recorded since the backup was taken (plays, notes, stored queries, pronunciations) will be lost.\n\nAre you sure you want to restore it?" 16 76; then
    return 1
  fi
  mariadb -h "$DESTHOST" -P "$DESTPORT" -u "$DESTUSR" -p"$DESTPWD" "$DESTDB" < "$RESTOREFILE"
  if [[ $? -eq 0 ]]; then IMPORTSUCCESS=1; fi
else
  return 1
fi

if [[ $IMPORTSUCCESS -eq 1 ]]; then
  dialog --backtitle "Giocoso Database Restore" --title " Database Restore Complete " --msgbox "\nThe database full restore has now been completed.\n" 15 70
else
  dialog --backtitle "Giocoso Database Restore" --title " Database Restore Failure! " --msgbox "\nThe database restore has failed for some reason.\n\nYou will need to restore the database manually: consult the user manual online for suggested ways of achieving this.\n\nQuitting back to the main menu in the meantime." 15 70
fi	
}

# =======================================================================================
#  Main code starts here. There are various scenarios:
#
#  1. Move core tables between databases: $1=move. Done via pipe-delimited text and
#     the source database might be a Giocoso 3 one, so we shouldn't assume anything 
#     about the source.
#  2. Backup the database: $1=backup. Backing up a Giocoso 4 database, so we can assume
#     the source connection details
#  3. Restore the database: $1=restore. Restoring to Giocoso 4, so we can assume the 
#     destination connection details.
#  4. Backup the database but non-interactively ($1=backup, $2=noprompt), so we can 
#     read the connection from the configuration file
# =======================================================================================

if [[ $1 == "backup" && $2 == "noprompt" ]]; then
  DEFAULTSRCDB="giocoso4"
  SOURCEHOST="$MYSQLIP"
  SOURCEPORT="$MYSQLPRT"
  if [[ -z $SOURCEHOST ]]; then SOURCEHOST="127.0.0.1"; fi
  if [[ -z $SOURCEPORT ]]; then SOURCEPORT="3306"; fi
  SOURCEUSR="giocoso4"
  SOURCEPWD="giocoso4"
  SOURCEDB="giocoso4"
  dump_db
  if [[ $BACKUPSUCCESS == "YES" ]]; then echo "Database backup complete."; elif [[ $BACKUPSUCCESS == "NODUMP" ]]; then echo "Database backup failed: no MariaDB dump program could be found."; else echo "Database backup failed."; fi
  return
fi

if [[ $1 == "move" ]]; then	
  if prompt_source; then
    prompt_dest
  fi

  if [[ $GOODSOURCE -eq 1 && $GOODDEST -eq 1 ]]; then
    move_plays
    move_notes
	move_sql
	move_phonemes
    MOVEOK=1
  fi

  if [[ $MOVEOK -eq 1 ]]; then
    # Report each kind of data separately. Counts are rows offered: any the destination already had are skipped.
    MOVEREPORT="\n  Plays:            $MOVE_PLAYS\n  Notes:            $MOVE_NOTES\n  Stored queries:   $MOVE_SQL\n  Pronunciations:   $MOVE_PHON\n"
    if [[ "$MOVE_PLAYS$MOVE_NOTES$MOVE_SQL$MOVE_PHON" == *FAILED* ]]; then
      dialog --backtitle "Giocoso Database Backup & Restore" --title " Database Import Incomplete! " --msgbox "\nNot everything could be copied between the databases:\n$MOVEREPORT\nSomething is wrong with your destination and/or source databases. Check both, then try again." 16 70
    else
      dialog --backtitle "Giocoso Database Backup & Restore" --title " Database Import Complete " --msgbox "\nData import between databases now complete:\n$MOVEREPORT" 15 70
    fi
  else
    dialog --backtitle "Giocoso Database Backup & Restore" --title " Database Import " --msgbox "\nData import between databases cancelled.\n" 15 70	
  fi
  
elif [[ $1 == "backup" ]]; then
  DEFAULTSRCDB="giocoso4"; DEFAULTIP="127.0.0.1"
  if prompt_source; then
    dump_db
	if [[ $BACKUPSUCCESS == "YES" ]]; then
	  dialog --backtitle "Giocoso Database Backup" --title " Database Backup " --msgbox "\nDatabase backup completed successfully.\n" 10 70
    elif [[ $BACKUPSUCCESS == "NODUMP" ]]; then
	 dialog --backtitle "Giocoso Database Backup" --title " Database Backup " --msgbox "\nDatabase backup failed: no MariaDB dump program could be found.\n" 10 70
    else 
	 dialog --backtitle "Giocoso Database Backup" --title " Database Backup " --msgbox "\nDatabase backup failed for some reason.\n" 10 70
    fi
  fi
  
elif [[ $1 == "restore" ]]; then	
  DEFAULTIP="127.0.0.1";DEFAULTDSTDB="giocoso4"
  if prompt_dest; then
    restore_db
  fi 
fi