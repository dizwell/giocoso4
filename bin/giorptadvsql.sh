#!/usr/bin/env bash
####################################################################
#
# giorptadvsql: routine for displaying a form into which
# a SQL statement can be typed, for reporting purposes.
# Submitted SQL is cleansed of 'drop', 'create', 'delete' and 
# 'update' keywords along with semi-colons.
#
####################################################################
RETURNTOMENU=0
REPORT_TITLE="Custom Giocoso Advanced SQL Report"
REPORT_FILE="$CONFDIR/txt/advreport.html"

function output_report {
if [[ -s "$CONFDIR/tmp/rpterror.html" ]]; then
  {
    cat <<EOF
<head>
<title>Giocoso Advanced SQL Error</title>
<link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/giocosoico.svg">
<style>
  .error {
    font-family: monospace;
    font-size: 14px;
    line-height: 1.5;
    white-space: pre-wrap;
    overflow-wrap: anywhere;
    background: #f5f5f5;
    border: 1px solid #ccc;
    padding: 12px;
    margin-top: 20px;
  }
</style>
</head>
<div style="display:flex; align-items:center; text-align:left; border-bottom:1px solid #ccc; margin-bottom:20px;">
  <a href="https://bbritten.com"><img src="file://$CONFDIR/art/giocosoico.png" style="width:80px; height:80px; margin-right:20px;"></a>
  <h1 style="margin:0;">Giocoso Advanced SQL Reporting: Error!</h1>
</div>
<pre class="error">
EOF
    cat "$CONFDIR/tmp/rpterror.html"
    printf '</pre>\n'
  } > "$CONFDIR/tmp/rpterror.tmp"
  mv "$CONFDIR/tmp/rpterror.tmp" "$CONFDIR/tmp/rpterror.html"
  REPORT_FILE="$CONFDIR/tmp/rpterror.html"
else
  REPORT_FILE="$CONFDIR/tmp/advreport.html"
fi
source "$CONFDIR/bin/giooutput.sh" "$REPORT_FILE"
}


SQLDEST="GLOBAL"

if ! [[ -d $CONFDIR/tmp ]]; then mkdir -p "$CONFDIR/tmp" 2>/dev/null; fi
FILENAME="$CONFDIR/tmp/sqlreport.txt"

if ! [[ -f $FILENAME ]]; then
  touch "$FILENAME"
fi

if ! [[ -f $CONFDIR/txt/advsqlreport.txt ]]; then
  touch "$CONFDIR/txt/advsqlreport.txt"
fi

while [[ $RETURNTOMENU -ne 1 ]]; do
  REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
  dialog --backtitle "Giocoso Advanced SQL Reporting - $SQLDEST" --title "  Enter your complete select query below " --extra-button --extra-label "Clear" --editbox "$CONFDIR/txt/advsqlreport.txt" 12 90 2>"$FILENAME"
  exitStatus=$?
  if [[ $exitStatus -eq 1 ]] || [[ $exitStatus -eq 255 ]]; then        # They've pressed Cancel or ESC
    RETURNTOMENU=1
  elif [[ $exitStatus -eq 3 ]]; then
    dialog --backtitle "Giocoso Advanced SQL Reporting - $SQLDEST" --title "  Enter your complete select query below " --extra-button --extra-label "Clear" --editbox "$FILENAME" 12 90 2>"$FILENAME"
	exitStatus=$?
    if [[ $exitStatus -eq 1 ]] || [[ $exitStatus -eq 255 ]]; then      # They've pressed Cancel or ESC
      RETURNTOMENU=1
    fi
  fi

  # Turn a multi-line query into a single line of text, which is needed to parse correctly.
  QUERY_STRING=$(<"$FILENAME")
  SQLTXT="${QUERY_STRING//$'\n'/ }"
  
  # Sanitation (Simple string removal)
  # makes the string search case-insensitive and removes naughty DDL and DML commands
  # Note this is not robust: no-one using Giocoso should imagine the platform is in any way secure.
  # This just stops little accidents!
  shopt -s nocasematch 
  SQLTXT="${SQLTXT//delete/}"
  SQLTXT="${SQLTXT//update/}"
  SQLTXT="${SQLTXT//drop/}"
  SQLTXT="${SQLTXT//create/}"
  SQLTXT="${SQLTXT//;/}"
  shopt -u nocasematch
  
  DISPLAYTXT=${SQLTXT//&/\&amp;}
  DISPLAYTXT=${DISPLAYTXT//</\&lt;}
  DISPLAYTXT=${DISPLAYTXT//>/\&gt;}
  DISPLAYTXT=${DISPLAYTXT//\"/\&quot;}
  DISPLAYTXT=${DISPLAYTXT//\'/\&#39;}
  
  echo "$SQLTXT" > "$CONFDIR/txt/advsqlreport.txt"

  if [[ ${#SQLTXT} -gt 0 ]]; then
    rm -rf "$REPORT_FILE"
    cat <<EOF > "$REPORT_FILE"
<head><title>Giocoso Reports</title></head>
<link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/giocosoico.svg">
<style>
  table { border-collapse: collapse; font-family: serif; font-size: 13px; width: 100%; }
  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }
  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }
  td:not(:first-child) { white-space: normal; }
  tr:nth-child(even) { background-color: #e0e0e0; }
  tr:hover { background-color: #ffffcc; }
  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }
</style>
<div style="display: flex; align-items: center; border-bottom: 1px solid #ccc; margin-bottom: 20px;">
  <a href="https://bbritten.com"><img src="file://$CONFDIR/art/giocosoico.png" style="width:80px; height:80px; margin-right:20px;"></a>
  <h1 style="margin: 0; padding-bottom: 0px;">$REPORT_TITLE</h1>
</div>
<div style="clear:both;"></div>
EOF

    "${PROCONN[@]}" -H -e "$SQLTXT" 2>"$CONFDIR/tmp/rpterror.html" >> "$REPORT_FILE"

    cat <<EOF >> "$REPORT_FILE"
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
<p class="footer">Total rows: $("${PROCONN[@]}" -N -s -e "SELECT count(*) FROM ($SQLTXT) AS t" 2>/dev/null)</p>
<p class="footer">Generated on: $REPORT_DATE</p>
<p class="footer">Query submitted: $DISPLAYTXT</p>
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
EOF
    output_report
  fi
done

rm -f "$CONFDIR/tmp/sqlreport.txt" 2>/dev/null
rm -f "$CONFDIR/tmp/rpterror.html" 2>/dev/null
clear; gmenuoptions reports