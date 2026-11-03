#!/usr/bin/env bash
####################################################################
#
# A generic function to output an HTML report in a chosen browser (or the system's
# default browser if one hasn't been specified or if one has been specified wrongly)
#
####################################################################
local BROWSER="${BROWSER//\"/}"
if [[ -z $1 ]]; then
  dialog --stdout --backtitle "Giocoso Report Generator" --msgbox "Something has gone wrong with generating this report.\\n\\nPress a key to return to the main menu" 10 80
else
  if [[ $OSFAMILY == "MACOS" ]]; then
    if command -v "$BROWSER" >/dev/null 2>&1; then
      "$BROWSER" "file://$REPORT_FILE" >/dev/null 2>&1
    elif open -Ra "$BROWSER" 2>/dev/null; then
      open -a "$BROWSER" "file://$REPORT_FILE" >/dev/null 2>&1
    else
      open "file://$REPORT_FILE" >/dev/null 2>&1
    fi     
  else
    if command -v "$BROWSER" >/dev/null 2>&1; then     
      "$BROWSER" "$REPORT_FILE" >/dev/null 2>&1
    else
      ${xdg_open:-xdg-open} "$REPORT_FILE" >/dev/null 2>&1
    fi
  fi
 fi