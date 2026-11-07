#!/usr/bin/env bash
####################################################################
#
# giorptexcludes: Report all composers who are exempted from the 
# timebar or who are hard-excluded from default selection.
#
####################################################################
REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_FILE="$CONFDIR/txt/excludes.html"
rm -rf "$REPORT_FILE" 2>/dev/null

function output_report {
source "$CONFDIR/bin/giooutput.sh" "$REPORT_FILE"
}

function excludes {
    XSQLSTMT="select composer as 'Composer' from global_excludes where selection='yes'"
	"${PROCONN[@]}" --html -e "$XSQLSTMT" 2>/dev/null >> "$REPORT_FILE"
}

function exempts {
    MSQLSTMT="select composer as 'Composer' from global_exempts where selection='yes'"
	"${PROCONN[@]}" --html -e "$MSQLSTMT" 2>/dev/null >> "$REPORT_FILE"
}

RPRTTITLE="Composers who are timebar exempted or excluded from default selection"
RPRTWIDTH=60

if [[ ${DURATIONS^^} == HOURS ]]; then
  DIVISOR=3600; DISPLAYTEXT="Hours"
else 
  DIVISOR=60;   DISPLAYTEXT="Minutes"
fi
	
cat <<EOF > "$REPORT_FILE"
<head><title>Giocoso Reports</title></head>
<link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/giocosoico.svg">
<style>
  table { border-collapse: collapse; font-family: serif; font-size: 13px; width: $RPRTWIDTH%; }
  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }
  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }
  th:first-child, td:first-child { width: auto; }
  th:nth-child(2), td:nth-child(2) { width: auto; }
  th:nth-child(3), td:nth-child(3) { width: 1%; white-space: nowrap; text-align: right; }
  th:nth-child(4), td:nth-child(4) { width: 1%; white-space: nowrap; text-align: right; }
  th:nth-child(5), td:nth-child(5) { width: 1%; white-space: nowrap; text-align: right; }
  th:nth-child(6), td:nth-child(6) { width: 1%; white-space: nowrap; text-align: right; }
  th:nth-child(7), td:nth-child(7) { width: 1%; white-space: nowrap; text-align: right; }
  td:nth-child(2) { white-space: normal; }
  tr:nth-child(even) { background-color: #e0e0e0; }
  tr:hover { background-color: #ffffcc; }
  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }
</style>
<div style="display: flex; align-items: center; border-bottom: 1px solid #ccc; margin-bottom: 20px;">
   <a href="https://bbritten.com"><img src="file://$CONFDIR/art/giocosoico.png" style="width:80px; height:80px; margin-right:20px;"></a>
  <h1 style="margin: 0; padding-bottom: 0px;">$RPRTTITLE</h1>
</div>
<div style="clear:both;"></div>
EOF

echo '<nav style="position: sticky; top: 0; background: white; padding: 8px 0; z-index: 1000; border-top: 1px solid #ccc; border-bottom: 1px solid #ccc;">' >> "$REPORT_FILE"
echo '<b><a href="#exempts">Composers Exempted</a> | <a href="#excludes">Composers Excluded</a></b>' >> "$REPORT_FILE"
echo '</nav>' >> "$REPORT_FILE"

echo '<h2 id="exempts">Composers Exempted from the configured Timebar</h2>' >> "$REPORT_FILE"
exempts
echo '<br><br>' >> "$REPORT_FILE"

echo '<h2 id="excludes">Composers Excluded from default music selection</h2>' >> "$REPORT_FILE"
excludes
echo '<br><br>' >> "$REPORT_FILE"

  # 3. Append the Footer and Row Count
  cat <<EOF >> "$REPORT_FILE"
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
<p class="footer">Generated on: $REPORT_DATE</p>
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
EOF

output_report

