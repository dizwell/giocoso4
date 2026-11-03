#!/usr/bin/env bash
####################################################################
#
# giorptlastplayed: Composer and Recordings by last played data
#
####################################################################
REPORT_FILE="$CONFDIR/txt/lastplayedrpt.html"
REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
rm -f "$REPORT_FILE" 2>/dev/null

function output_report {
source "$CONFDIR/bin/giooutput.sh" "$REPORT_FILE"
}

function composer_lastplayed {
REPORT_TITLE="Days since composers were last played"
SQLSTMT="select composer as 'Composer', concat(day(max(playdate)), case when day(max(playdate)) in (1,21,31) then 'st' when day(max(playdate)) in (2,22) then 'nd' when day(max(playdate)) in (3,23) then 'rd' else 'th' end, ' ', date_format(max(playdate), '%M %Y')) as 'Date Last Played', format(datediff(curdate(), date(max(playdate))), 0) as 'Days Ago' from global_plays group by composer order by date(max(playdate)) asc, composer asc"
          
# 1. Start the file with the custom Header/Styles
  cat <<EOF > "$REPORT_FILE"
<head><title>Giocoso Reports</title></head>
<link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/giocosoico.svg">
<style>
  table { border-collapse: collapse; font-family: serif; font-size: 13px; width: 60%; }
  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }
  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }
  th:first-child, td:first-child { width: 30%; }
  th:nth-child(2), td:nth-child(2) { width: 15%; text-align: center; }
  th:nth-child(3), td:nth-child(3) { width: 15%; text-align: right; }
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

"${PROCONN[@]}" --html -e "$SQLSTMT" 2>/dev/null >> "$REPORT_FILE"

cat <<'EOF' >> "$REPORT_FILE"
<script>
document.addEventListener('DOMContentLoaded', function() {
  const table = document.querySelector('table');

  if (!table) return;

  const allRows = Array.from(table.querySelectorAll('tr'));
  const header = allRows[0];
  const rows = allRows.slice(1);
  const perPage = 50;
  const totalPages = Math.ceil(rows.length / perPage);

  if (totalPages <= 1) return;

  const nav = document.createElement('div');
  nav.style.margin = '10px 0';
  nav.style.fontFamily = 'serif';
  nav.style.fontSize = '13px';

  const previous = document.createElement('button');
  previous.textContent = 'Previous';

  const page = document.createElement('input');
  page.type = 'number';
  page.min = 1;
  page.max = totalPages;
  page.value = 1;
  page.style.width = '85px';
  page.style.textAlign = 'center';
  page.style.margin = '0 5px';

  const next = document.createElement('button');
  next.textContent = 'Next';

  const info = document.createElement('span');
  info.style.marginLeft = '15px';

  nav.appendChild(previous);
  nav.appendChild(page);
  nav.appendChild(next);
  nav.appendChild(info);

  table.parentNode.insertBefore(nav, table);

  function showPage(number) {
    number = parseInt(number);

    if (isNaN(number)) number = 1;
    if (number < 1) number = 1;
    if (number > totalPages) number = totalPages;

    page.value = number;

    const start = (number - 1) * perPage;
    const end = start + perPage;

    header.style.display = '';

    rows.forEach((row, i) => {
      row.style.display = (i >= start && i < end) ? '' : 'none';
    });

    info.textContent = 'Rows ' + (start + 1) + '–' +
                       Math.min(end, rows.length) +
                       ' of ' + rows.length;

    previous.disabled = number === 1;
    next.disabled = number === totalPages;
  }

  previous.onclick = function() {
    showPage(parseInt(page.value) - 1);
  };

  next.onclick = function() {
    showPage(parseInt(page.value) + 1);
  };

  page.addEventListener('change', function() {
    showPage(page.value);
  });

  page.addEventListener('keydown', function(event) {
    if (event.key === 'Enter') {
      showPage(page.value);
      page.blur();
    }
  });

  showPage(1);
});
</script>
EOF

# 3. Append the Footer and Row Count
  cat <<EOF >> "$REPORT_FILE"
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
<p class="footer">Total rows: $("${PROCONN[@]}" -N -s -e "SELECT count(*) FROM ($SQLSTMT) AS t" 2>/dev/null)</p>
<p class="footer">Generated on: $REPORT_DATE</p>
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
EOF

output_report
}

function composition_lastplayed {
REPORT_TITLE="Days since recordings were last played (oldest 1000)"
SQLSTMT="select composer as 'Composer', composition as 'Recording', concat(day(max(playdate)), case when day(max(playdate)) in (1,21,31) then 'st' when day(max(playdate)) in (2,22) then 'nd' when day(max(playdate)) in (3,23) then 'rd' else 'th' end, ' ', date_format(max(playdate), '%M %Y')) as 'Date Last Played', format(datediff(curdate(), date(max(playdate))), 0) as 'Days Ago' from global_plays group by composer, composition order by date(max(playdate)) asc, composition asc limit 1000"
          
# 1. Start the file with the custom Header/Styles
cat <<EOF > "$REPORT_FILE"
<head><title>Giocoso Reports</title></head>
<link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/giocosoico.svg">
<style>
  table { border-collapse: collapse; font-family: serif; font-size: 13px; width: 100%; }
  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }
  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }
  th:first-child, td:first-child { width: 25%; }
  th:nth-child(2), td:nth-child(2) { width: 45%; }
  th:nth-child(3), td:nth-child(3) { width: 15%; text-align: center; }
  th:nth-child(4), td:nth-child(4) { width: 10%; text-align: center; }
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

"${PROCONN[@]}" --html -e "$SQLSTMT" 2>/dev/null >> "$REPORT_FILE"

cat <<'EOF' >> "$REPORT_FILE"
<script>
document.addEventListener('DOMContentLoaded', function() {
  const table = document.querySelector('table');

  if (!table) return;

  const allRows = Array.from(table.querySelectorAll('tr'));
  const header = allRows[0];
  const rows = allRows.slice(1);
  const perPage = 50;
  const totalPages = Math.ceil(rows.length / perPage);

  if (totalPages <= 1) return;

  const nav = document.createElement('div');
  nav.style.margin = '10px 0';
  nav.style.fontFamily = 'serif';
  nav.style.fontSize = '13px';

  const previous = document.createElement('button');
  previous.textContent = 'Previous';

  const page = document.createElement('input');
  page.type = 'number';
  page.min = 1;
  page.max = totalPages;
  page.value = 1;
  page.style.width = '85px';
  page.style.textAlign = 'center';
  page.style.margin = '0 5px';

  const next = document.createElement('button');
  next.textContent = 'Next';

  const info = document.createElement('span');
  info.style.marginLeft = '15px';

  nav.appendChild(previous);
  nav.appendChild(page);
  nav.appendChild(next);
  nav.appendChild(info);

  table.parentNode.insertBefore(nav, table);

  function showPage(number) {
    number = parseInt(number);

    if (isNaN(number)) number = 1;
    if (number < 1) number = 1;
    if (number > totalPages) number = totalPages;

    page.value = number;

    const start = (number - 1) * perPage;
    const end = start + perPage;

    header.style.display = '';

    rows.forEach((row, i) => {
      row.style.display = (i >= start && i < end) ? '' : 'none';
    });

    info.textContent = 'Rows ' + (start + 1) + '–' +
                       Math.min(end, rows.length) +
                       ' of ' + rows.length;

    previous.disabled = number === 1;
    next.disabled = number === totalPages;
  }

  previous.onclick = function() {
    showPage(parseInt(page.value) - 1);
  };

  next.onclick = function() {
    showPage(parseInt(page.value) + 1);
  };

  page.addEventListener('change', function() {
    showPage(page.value);
  });

  page.addEventListener('keydown', function(event) {
    if (event.key === 'Enter') {
      showPage(page.value);
      page.blur();
    }
  });

  showPage(1);
});
</script>
EOF

# 3. Append the Footer and Row Count
  cat <<EOF >> "$REPORT_FILE"
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
<p class="footer">Total rows: $("${PROCONN[@]}" -N -s -e "SELECT count(*) FROM ($SQLSTMT) AS t" 2>/dev/null), comprising the work of $("${PROCONN[@]}" -N -s -e "SELECT count(distinct composer) FROM ($SQLSTMT) AS t" 2>/dev/null) different composers</p>
<p class="footer">Generated on: $REPORT_DATE</p>
<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">
EOF

output_report
}

if [[ $1 == "composer" ]]; then
  composer_lastplayed
else
  composition_lastplayed
fi