#!/usr/bin/env bash
####################################################################
#
# giorptaggstats: An aggregate statistics report
#
####################################################################
REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_FILE="$CONFDIR/txt/aggstats.html"
rm -f "$REPORT_FILE" 2>/dev/null

function output_report {
source "$CONFDIR/bin/giooutput.sh" "$REPORT_FILE"
}

REPORT_TITLE="Giocoso 4 : Music Collection Aggregate Statistics Report"
SQLTXT1="select statnum as 'Stat', statdesc 'Statistic', case when statnum=6 then count when statnum=7 then format(count,1) when statnum=9 then format(count,2) else format(count,0) end as 'Value' from agg_stats"
SQLTXT2="select stat as 'Stat', description as 'Duration', format(total,0) as 'Total No.', format(played,0) as 'No. Played', format(unplayed,0) as 'No. Unplayed' from agg_hist union select '7' COLLATE utf8mb4_uca1400_ai_ci, 'Grand Totals' COLLATE utf8mb4_uca1400_ai_ci, format(sum(total),0), format(sum(played),0), format(sum(unplayed),0) from agg_hist"
SQLTXT3="select Genre, Hours, Percentage, HoursPlayed as 'Hours Played', PercentagePlayed as 'Percentage Played', concat(case when PercentagePlayed - Percentage > 0 then '+' else '' end, format(PercentagePlayed - Percentage,2)) as 'Over/Underplayed %' from (select gr.genre as Genre, format(sum(gr.duration)/3600,2) as Hours, format(sum(gr.duration) / (select sum(duration) from global_recordings) * 100, 2) as Percentage, format(coalesce(ps.play_seconds,0)/3600,2) as HoursPlayed, round(coalesce(ps.play_seconds,0) / (select sum(r.duration) from global_plays p join global_recordings r on p.rechashvalue=r.rechashvalue) * 100, 2) as PercentagePlayed from global_recordings gr left join (select r.genre, sum(r.duration) as play_seconds from global_plays p join global_recordings r on p.rechashvalue=r.rechashvalue group by r.genre) ps on ps.genre=gr.genre group by gr.genre, ps.play_seconds
) x
union all
select 'Grand Totals', format(sum(duration)/3600,2), 100.00, format((select sum(r.duration) from global_plays p join global_recordings r on p.rechashvalue=r.rechashvalue)/3600,2), 100.00, '0.00' from global_recordings
order by case when Genre='Grand Totals' then 1 else 0 end, cast(replace(Percentage,',','') as decimal(10,2)) desc"
SQLTXT4="with top20 as (
    select performer, count(*) as recordings
    from global_recordings
    group by performer
    order by recordings desc
    limit 20
),
plays as (
    select performer, count(*) as plays
    from global_plays
    where performer in (select performer from top20)
    group by performer
),
combined as (
    select
        t.performer,
        t.recordings,
        coalesce(p.plays,0) as plays
    from top20 t
    left join plays p on p.performer=t.performer
)
select Performer, Recordings, RecordingPercentage as 'Percentage', Plays, PlayPercentage as 'Percentage Played', OverUnderplayed as 'Over/Underplayed %'
from (
    select
        performer,
        recordings as Recordings,
        round(recordings / sum(recordings) over () * 100,2) as RecordingPercentage,
        plays as Plays,
        round(plays / sum(plays) over () * 100,2) as PlayPercentage,
        concat(case when (plays / sum(plays) over () * 100) - (recordings / sum(recordings) over () * 100) > 0 then '+' else '' end, format((plays / sum(plays) over () * 100) - (recordings / sum(recordings) over () * 100),2)) as OverUnderplayed,
        1 as sort_order
    from combined

    union all

    select
        'Grand Totals',
        sum(recordings),
        100.00,
        sum(plays),
        100.00,
        '0.00',
        2
    from combined
) x
order by sort_order, Recordings desc;"
		  
# 1. First Report
  cat <<EOF > "$REPORT_FILE"
<head><title>Giocoso Reports</title></head>
<link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/giocosoico.svg">
<style>
  table { border-collapse: collapse; font-family: serif; font-size: 13px; }
  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }
  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }
  #aggregate-report th:first-child, #aggregate-report td:first-child,
  #duration-report th:first-child, #duration-report td:first-child { display: none; }
  th:nth-child(2), td:nth-child(2) { width: 50%;  min-width: 300px; }
  th:nth-child(3), td:nth-child(3) { width: 10%; text-align: right; }
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
echo '<h2>Overall Music Collection Statistics</h2>' >> "$REPORT_FILE"

  # 2. Inject the Table using your PROCONN array
  # Note: --html produces the <table> tags automatically
  echo '<div id="aggregate-report">' >> "$REPORT_FILE"
  "${PROCONN[@]}" --html -e "$SQLTXT1" 2>/dev/null >> "$REPORT_FILE"
  echo '</div>' >> "$REPORT_FILE"

  # 3. Append the Footer and Row Count
  echo '<p class="footer"><a href="https://bbritten.com/notes/statexplain" target="_blank">See this page for an explanation of the statistics</a></p>' >> "$REPORT_FILE"
  cat <<EOF >> "$REPORT_FILE"
<p class="footer"></p>
EOF

# 2nd Report
echo '<br>' >> "$REPORT_FILE"
echo '<hr>' >> "$REPORT_FILE"
echo '<h2>Breakdown of Recordings and Plays by Duration</h2>' >> "$REPORT_FILE"

  cat <<EOF >> "$REPORT_FILE"
<head><title>Giocoso Reports</title></head>
<link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/giocosoico.svg">
<style>
  table { border-collapse: collapse; font-family: serif; font-size: 13px; }
  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }
  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }
  th:nth-child(3), td:nth-child(3) { text-align: right; }
  th:nth-child(4), td:nth-child(4) { text-align: right; }
  th:nth-child(5), td:nth-child(5) { text-align: right; }
  td:not(:first-child) { white-space: normal; }
  tr:nth-child(even) { background-color: #e0e0e0; }
  #duration-report tr:last-child { font-weight: bold; color: #2e7d32; background-color: #e8f5e9 !important; }
  tr:hover { background-color: #ffffcc; }
  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }
</style>
<div style="clear:both;"></div>
EOF

  # 2. Inject the Table using your PROCONN array
  # Note: --html produces the <table> tags automatically
  echo '<div id="duration-report">' >> "$REPORT_FILE"
  "${PROCONN[@]}" --html -e "$SQLTXT2" 2>/dev/null >> "$REPORT_FILE"
  echo '</div>' >> "$REPORT_FILE"
  
  # 3. Append the Footer and Row Count
  cat <<EOF >> "$REPORT_FILE"
<p class="footer"></p>
EOF

# 3rd Report
echo '<br>' >> "$REPORT_FILE"
echo '<hr>' >> "$REPORT_FILE"
echo '<h2>Breakdown of Recordings & Plays by Genre</h2>' >> "$REPORT_FILE"

  cat <<EOF >> "$REPORT_FILE"
<head><title>Giocoso Reports</title></head>
<link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/giocosoico.svg">
<style>
  table { border-collapse: collapse; font-family: serif; font-size: 13px; }
  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }
  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }
  #genre-report th:nth-child(2), #genre-report td:nth-child(2) { width: 90px; min-width: 0; text-align: right; }
  #genre-report th:nth-child(3), #genre-report td:nth-child(3) { width: 80px; min-width: 0; text-align: right; } 
  #genre-report th:nth-child(6), #genre-report td:nth-child(6) { width: 130px; min-width: 0; text-align: right; }  
  td:not(:first-child) { white-space: normal; }
  tr:nth-child(even) { background-color: #e0e0e0; }
  #genre-report tr:last-child { font-weight: bold; color: #2e7d32; background-color: #e8f5e9 !important; }
  tr:hover { background-color: #ffffcc; }
  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }
</style>
<div style="clear:both;"></div>
EOF

  # 2. Inject the Table using your PROCONN array
  # Note: --html produces the <table> tags automatically
  echo '<div id="genre-report">' >> "$REPORT_FILE"
  "${PROCONN[@]}" --html -e "$SQLTXT3" 2>/dev/null >> "$REPORT_FILE"
  echo '</div>' >> "$REPORT_FILE"
  
  # 3. Append the Footer and Row Count
  cat <<EOF >> "$REPORT_FILE"
<p class="footer"></p>
EOF


# 4th Report
echo '<br>' >> "$REPORT_FILE"
echo '<hr>' >> "$REPORT_FILE"
echo '<h2>Breakdown of Recordings & Plays by Distinguishing Artist (top 20)</h2>' >> "$REPORT_FILE"

  cat <<EOF >> "$REPORT_FILE"
<head><title>Giocoso Reports</title></head>
<link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/giocosoico.svg">
<style>
  table { border-collapse: collapse; font-family: serif; font-size: 13px; }
  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }
  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }
  #artist-report th:nth-child(2), #artist-report td:nth-child(2) { width: 90px; min-width: 0; text-align: right; }
  #artist-report th:nth-child(3), #artist-report td:nth-child(3) { width: 80px; min-width: 0; text-align: right; } 
  #artist-report th:nth-child(6), #artist-report td:nth-child(6) { width: 130px; min-width: 0; text-align: right; }  
  td:not(:first-child) { white-space: normal; }
  tr:nth-child(even) { background-color: #e0e0e0; }
  #artist-report tr:last-child { font-weight: bold; color: #2e7d32; background-color: #e8f5e9 !important; }
  tr:hover { background-color: #ffffcc; }
  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }
</style>
<div style="clear:both;"></div>
EOF

  # 2. Inject the Table using your PROCONN array
  # Note: --html produces the <table> tags automatically
  echo '<div id="artist-report">' >> "$REPORT_FILE"
  "${PROCONN[@]}" --html -e "$SQLTXT4" 2>/dev/null >> "$REPORT_FILE"
  echo '</div>' >> "$REPORT_FILE"
  
  # 3. Append the Footer and Row Count
  cat <<EOF >> "$REPORT_FILE"
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
<p class="footer">Generated on: $REPORT_DATE <br>Using a Giocoso server database at: $MYSQLIP</p>
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
EOF

  output_report
