#!/usr/bin/env bash
####################################################################
#
# gioexempts: populates a global_exempts table with composer names
# extracted from global_recordings and with a yes/no flag. If a 
# composer is listed with a 'yes' flag, they are considered exempt
# from the usual timebar play restriction.
#
####################################################################
# Add any new composers to global_exempts, leaving existing selections untouched
"${PROCONN[@]}" -e "
insert into global_exempts (composer, selection)
select distinct gr.composer, 'no'
from global_recordings gr
left join global_exempts ge on gr.composer = ge.composer
where ge.composer is null
" 2>/dev/null

# Delete any old composers from exempts that no longer exist in recordings
"${PROCONN[@]}" -e "delete from global_exempts
where composer not in (select distinct composer from global_recordings)" 2>/dev/null

# Build the dialog checklist from global_exempts
"${PROCONN[@]}" -N -B -e "
select composer, selection
from global_exempts
order by composer
" > "$CONFDIR/tmp/exemptcomposers.txt"

CHECKLISTARGS=()

while IFS=$'\t' read -r composer selection; do
  if [[ $selection == "yes" ]]; then
    status="ON"
  else
    status="OFF"
  fi

  CHECKLISTARGS+=("$composer" "" "$status")
done < "$CONFDIR/tmp/exemptcomposers.txt"

dialog --backtitle "Giocoso Composer Timebar Exemptions" \
  --title " Select composers to exempt from the standard timebar " \
  --separate-output \
  --checklist "Toggle composers on or off:" \
  20 90 14 \
  "${CHECKLISTARGS[@]}" \
  2>"$CONFDIR/tmp/exemptselected.txt"

DIALOGSTATUS=$?

if [[ $DIALOGSTATUS -eq 0 ]]; then

  # Start by setting every composer to unselected
  "${PROCONN[@]}" -e "update global_exempts set selection='no'" 2>/dev/null

  # Set the composers selected in the dialog to yes
  while IFS= read -r composer; do
    composer="${composer//\'/\'\'}"
    "${PROCONN[@]}" -e "update global_exempts set selection='yes' where composer='$composer'"
  done < <(sed 's/^"//;s/"$//' "$CONFDIR/tmp/exemptselected.txt")

fi