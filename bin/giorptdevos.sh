#!/usr/bin/env bash
####################################################################
# giorptdevos: Reporting on plays by device and operating system
####################################################################
REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_FILE="$CONFDIR/txt/devices.html"
rm -rf "$REPORT_FILE" 2>/dev/null

function output_report {
source "$CONFDIR/bin/giooutput.sh" "$REPORT_FILE"
}

function plays_by_device {
tput cup 3 65; tput setaf $MAINTEXT; echo -en "GLOBAL Per-Device Play Report"; tput cup 5 0;
DEVSTMT="select Device, PlayCount as 'Play Count',
       concat(floor(secs/3600), ':', lpad(floor(mod(secs,3600)/60),2,'0'), ':', lpad(floor(mod(secs,60)),2,'0')) as 'Play Hours',
       round(secs/86400,1) as 'Play Days',
       PlayPercent as 'Play Percent'
from (
  select coalesce(nullif(trim(devicename),''), 'No Device Specified') as Device,
         count(*) as PlayCount,
         sum(time_to_sec(duration)) as secs,
         round(count(*)/(select count(*) from global_plays)*100,2) as PlayPercent
  from global_plays
  group by 1
) x
order by PlayCount desc"
"${PROCONN[@]}" --html -e "$DEVSTMT" 2>/dev/null >> "$REPORT_FILE"
}

function plays_by_os {
tput cup 3 65; tput setaf $MAINTEXT; echo -en "GLOBAL Per-O/S Play Report"; tput cup 5 0;
OSSTMT="select OperatingSystem as 'Operating System', PlayCount as 'Play Count',
       concat(floor(secs/3600), ':', lpad(floor(mod(secs,3600)/60),2,'0'), ':', lpad(floor(mod(secs,60)),2,'0')) as 'Play Hours',
       round(secs/86400,1) as 'Play Days',
       PlayPercent as 'Play Percent'
from (
  select coalesce(nullif(trim(os_type),''), 'No OS Specified') as OperatingSystem,
         count(*) as PlayCount,
         sum(time_to_sec(duration)) as secs,
         round(count(*)/(select count(*) from global_plays)*100,2) as PlayPercent
  from global_plays
  group by 1
) x
order by 2 desc"
"${PROCONN[@]}" --html -e "$OSSTMT" 2>/dev/null >> "$REPORT_FILE"
}

GBLSQLSTMT="select count(*) from (
select count(*) from global_plays group by coalesce(nullif(trim(devicename),''),'No Device Specified') union all
select count(*) from global_plays group by coalesce(nullif(trim(os_type),''),'No OS Specified')) x"

RPRTTITLE="Plays by Device and Operating System"
RPRTWIDTH=60

cat <<EOF > "$REPORT_FILE"
<head><title>Giocoso Reports</title></head>
<link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/giocosoico.svg">
<style>
  table { border-collapse: collapse; font-family: serif; font-size: 13px; width: $RPRTWIDTH%; }
  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }
  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }
  th:first-child, td:first-child { width: auto; }
  th:nth-child(2), td:nth-child(2) { width: auto; text-align: right; }
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

  # 2. Inject the Table using the PROCONN array
  # Note: --html produces the <table> tags automatically
  plays_by_device
  echo '<br><br>' >> "$REPORT_FILE"
  plays_by_os
  

  # 3. Append the Footer and Row Count
  cat <<EOF >> "$REPORT_FILE"
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
<p class="footer">Total rows: $("${PROCONN[@]}" -N -s -e "$GBLSQLSTMT" 2>/dev/null)</p>
<p class="footer">Generated on: $REPORT_DATE</p>
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
EOF

tput cup 25 4
output_report
