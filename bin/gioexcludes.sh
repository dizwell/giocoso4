#!/usr/bin/env bash
####################################################################
#
# gioexcludes: populates a global_exempts table with composer names
# extracted from global_recordings and with a yes/no flag. If a 
# composer is listed with a 'yes' flag, they are considered exempt
# from the usual timebar play restriction.
#
####################################################################

function display_form {
# Add any new composers to global_exempts, leaving existing selections untouched
"${PROCONN[@]}" -e "
insert into global_excludes (composer, selection)
select distinct gr.composer, 'no'
from global_recordings gr
left join global_excludes ge on gr.composer = ge.composer
where ge.composer is null
" 2>/dev/null

# Delete any old composers from exempts that no longer exist in recordings
"${PROCONN[@]}" -e "delete from global_excludes
where composer not in (select distinct composer from global_recordings)" 2>/dev/null

# Build the dialog checklist from global_exempts
"${PROCONN[@]}" -N -B -e "
select composer, selection
from global_excludes
order by composer
" > "$CONFDIR/tmp/excludescomposers.txt"

CHECKLISTARGS=()

while IFS=$'\t' read -r composer selection; do
  if [[ $selection == "yes" ]]; then
    status="ON"
  else
    status="OFF"
  fi

  CHECKLISTARGS+=("$composer" "" "$status")
done < "$CONFDIR/tmp/excludescomposers.txt"

dialog --backtitle "Giocoso Composer Exclusions" \
  --title " Choose composers to exclude from selection " \
  --extra-button --extra-label "Clear All" \
  --separate-output \
  --checklist "Toggle composers on or off:" \
  20 90 14 \
  "${CHECKLISTARGS[@]}" \
  2>"$CONFDIR/tmp/excludesselected.txt"

DIALOGSTATUS=$?
}

function process_selections {
if [[ $DIALOGSTATUS -eq 0 ]]; then
  # Start by setting every composer to unselected
  "${PROCONN[@]}" -e "update global_excludes set selection='no'" 2>/dev/null

  # Set the composers selected in the dialog to yes
  while IFS= read -r composer; do
    composer="${composer//\'/\'\'}"
    "${PROCONN[@]}" -e "update global_excludes set selection='yes' where composer='$composer'"
  done < <($SEDPROG 's/^"//;s/"$//' "$CONFDIR/tmp/excludesselected.txt")

elif [[ $DIALOGSTATUS -eq 3 ]]; then
	"${PROCONN[@]}" -e "update global_excludes set selection='no'" 2>/dev/null
	  display_form
	  process_selections
fi
}

display_form
process_selections