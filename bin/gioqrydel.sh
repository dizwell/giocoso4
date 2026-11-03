#!/usr/bin/env bash
####################################################################
#
# gioqrydel: displays stored queries, allowing for selection, and 
# then deletes anything selected.
#
####################################################################
function delete_sqls {
QUERYLIST=()
while IFS= read -r QUERYNAME; do
  QUERYLIST+=("$QUERYNAME" "$QUERYNAME" off)
done < <("${PROCONN[@]}" -N -B -e "select query_name from stored_queries order by query_name")

CHOSENQUERIES=$(dialog --separate-output --no-tags --backtitle "Managing Stored Queries" --title " Delete Stored Queries " --checklist "\nSelect the queries to delete:\n" 15 90 0 "${QUERYLIST[@]}" 3>&1 1>&2 2>&3 3>&-)

if [[ $? -eq 0 ]]; then
  while IFS= read -r QUERY_NAME; do
    QUERY_NAME="${QUERY_NAME//\'/\'\'}"
    "${PROCONN[@]}" -N -B -e "delete from stored_queries where query_name='$QUERY_NAME';" 2>/dev/null
  done <<< "$CHOSENQUERIES"
fi
}

delete_sqls	

		