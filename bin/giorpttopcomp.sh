#!/usr/bin/env bash
####################################################################
#
# giorpttopcomp: Report top composers by plays or accumulated play
# time, along with a report of plays grouped by genre.
#
####################################################################
REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_FILE="$CONFDIR/txt/topcomposers.html"
rm -rf "$REPORT_FILE" 2>/dev/null

function output_report {
source "$CONFDIR/bin/giooutput.sh" "$REPORT_FILE"
}

function play_durations {
    DURSQLSTMT="select '1' as '#', Composer as 'Composer', round(sum(substr(duration,1,2)*3600 + substr(duration,4,2)*60 + substr(duration,7,2))/$DIVISOR,2) as 'Total Duration', count(*) as 'Number of Plays' from global_plays group by composer
    union
    select '2', 'Grand Totals', round(sum(substr(duration,1,2)*3600 + substr(duration,4,2)*60 + substr(duration,7,2))/$DIVISOR,2), count(*) from global_plays order by 1 asc, 3 desc"
	"${PROCONN[@]}" --html -e "$DURSQLSTMT" 2>/dev/null >> "$REPORT_FILE"
}

function play_counts {
    CNTSQLSTMT="select '1' as '#', Composer, count(*) as 'Number of Plays', round(sum(substr(duration,1,2)*3600 + substr(duration,4,2)*60 + substr(duration,7,2))/$DIVISOR,2) as 'Total Duration' from global_plays group by composer 
    union
    select '2', 'Grand Totals', count(*), round(sum(substr(duration,1,2)*3600 + substr(duration,4,2)*60 + substr(duration,7,2))/$DIVISOR,2) from global_plays order by 1 asc, 3 desc"
	"${PROCONN[@]}" --html -e "$CNTSQLSTMT" 2>/dev/null >> "$REPORT_FILE"
}

function genre_analysis {
    ANLSQLSTMT="with records as (select genre, count(*) as reccount from global_recordings group by genre), 
                     players as (select genre, count(*) as playcount from global_plays group by genre),
                     calculated as (select records.genre as Genre, reccount, ifnull(playcount, 0) as playcount,
                     sum(reccount) over() as total_rec, sum(ifnull(playcount, 0)) over() as total_play from records left join players on records.genre = players.genre)
                     select 1 as '#', Genre, format(reccount,0) AS 'Recordings Count', 
				                        format(playcount,0) AS 'Played Count', 
										round((reccount / total_rec) * 100, 2) as 'Recording %', 
										round((playcount / total_play) * 100, 2) as 'Played %', 
                     if(round(((reccount / total_rec) - (playcount / total_play)) * 100, 2) > 0, concat('+', format(((reccount / total_rec) - (playcount / total_play)) * 100, 2)), if(round(((reccount / total_rec) - (playcount / total_play)) * 100, 2) < 0, format(((reccount / total_rec) - (playcount / total_play)) * 100, 2), '0.00')) as 'Difference %'
				     from calculated
                union all
                     select 2, 'Grand Totals', format(sum(reccount),0), 100.00, format(sum(playcount),0), 100.00, '' from calculated
                     order by 1, 2"
	"${PROCONN[@]}" --html -e "$ANLSQLSTMT" 2>/dev/null >> "$REPORT_FILE"
}

RPRTTITLE="Top Composers and Genre breakdown"
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
  th:first-child, td:first-child { display: none; }
  th:nth-child(2), td:nth-child(2) { width: auto; }
  th:nth-child(3), td:nth-child(3) { width: 1%; white-space: nowrap; text-align: right; }
  th:nth-child(4), td:nth-child(4) { width: 1%; white-space: nowrap; text-align: right; }
  th:nth-child(5), td:nth-child(5) { width: 1%; white-space: nowrap; text-align: right; }
  th:nth-child(6), td:nth-child(6) { width: 1%; white-space: nowrap; text-align: right; }
  th:nth-child(7), td:nth-child(7) { width: 1%; white-space: nowrap; text-align: right; }
  td:nth-child(2) { white-space: normal; }
  tr:nth-child(even) { background-color: #e0e0e0; }
  tr:last-child { font-weight: bold; color: #2e7d32; background-color: #e8f5e9 !important; }
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
echo '<b><a href="#durations">Top Composers by Play Durations</a> | <a href="#counts">Top Composers by Play Counts</a> | <a href="#genres">Plays & Recordings by Genre Breakdown</a></b>' >> "$REPORT_FILE"
echo '</nav>' >> "$REPORT_FILE"

echo '<h2 id="durations">Top Composers ordered by Play Durations</h2>' >> "$REPORT_FILE"
play_durations
echo '<br><br>' >> "$REPORT_FILE"

echo '<h2 id="counts">Top Composers ordered by Play Counts</h2>' >> "$REPORT_FILE"
play_counts
echo '<br><br>' >> "$REPORT_FILE"

echo '<h2 id="genres">Plays & Recordings by Genre Breakdown</h2>' >> "$REPORT_FILE"
genre_analysis

  # 3. Append the Footer and Row Count
  cat <<EOF >> "$REPORT_FILE"
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
<p class="footer">Generated on: $REPORT_DATE</p>
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
EOF

output_report