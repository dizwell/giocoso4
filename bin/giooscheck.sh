#!/usr/bin/env bash
####################################################################
#
# Queries the nature of the OS it's running on and sees if software
# prerequisites are present.
#
####################################################################
COPYRIGHT="2019-2026"                             # Copyright years, used by every screen that displays them (set here, as bin/ is always current)
pending=0

# If we're not running at least version 4.2 of Bash, all our maths break!
# -----------------------------------------------------------------------------
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2) )); then
  echo "You are running an ancient version of Bash and Giocoso cannot continue."
  exit 1
fi

if [[ -z $LOGOZ ]]; then
  LOGOZ=6
  MAINTEXT=15
  DRAWLINES=2
fi

if [[ -z $1 ]]; then set -- "checkonly"; fi
if [[ $1 == "install" ]]; then
  CHECKONLY=0
else
  CHECKONLY=1
fi

function print_header {
clear
tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
tput cup  1 4; tput setaf $LOGOZ; echo -e "♬♪ Giocoso Music Player Installer ♬♪"
tput cup  2 4; tput setaf $LOGOZ; echo -e "Copyright © H. Rogers $COPYRIGHT"
tput cup  3 4; tput setaf $LOGOZ; echo -e "Version $PROGVERSION"
}

function check_updates {
if [[ $pending -gt 0 ]]; then
  print_header
  tput cup 6 4; tput setaf $ALERT; echo "!! You have pending OS software updates !!"
  tput cup 8 4; tput setaf $MAINTEXT; echo "Do you want to quit the current installation and apply them yourself, or do you wish to proceed with installing Giocoso regardless? [q/p] " | fold -s -w 76 | sed '2,$s/^/    /'
  read -s -n 1 choice
  
  # Default to 'q' if the user just presses Enter, or if they type 'q'/'Q'
  case "${choice:-q}" in
    [pP]* ) 
	      echo "    Proceeding as requested. Hang on..."
          PROCEED=1
          ;;
        * ) 
          echo "    Exiting script. Please update your system manually."
          reset
          rm -f gio4inst
          exit 1
          ;;
   esac
fi    
}

function determine_role {
if dialog --title " Determining Giocoso Role " --yes-label "Server" --no-label "Client" --defaultno --yesno "\nIs this installation going to act as a server to other installs, or just be a client installation, connecting to remote servers?" 8 80; then
  GIOSERVER="yes"
else
  GIOSERVER="no"
fi
tput cup 25 4; tput setaf $MAINTEXT; echo "Please wait..."
}

function maria_components {	
# Some distros/OSes have one package that does both client and server
# Some have different packages for server installs than client ones
# Therefore, we need to test for OSFAMILY and respond accordingly.  
case "$OSFAMILY" in
  UBUNTU|DEBIAN|RASPBIAN)
	  if [[ $GIOSERVER == "yes" ]]; then
	    MARIA_PKG=mariadb-server
		echo "MARIADB: Server package $MARIA_PKG specified" >> "$CONFDIR/txt/install-log.txt"
	  else
	    MARIA_PKG=mariadb-client
		echo "MARIADB: Client package $MARIA_PKG specified" >> "$CONFDIR/txt/install-log.txt"
	  fi
	  ;;
  RHEL|FEDORA)
	  if [[ $GIOSERVER == "yes" ]]; then
	    MARIA_PKG=mariadb-server
		echo "MARIADB: Server package $MARIA_PKG specified" >> "$CONFDIR/txt/install-log.txt"
	  else
	    MARIA_PKG=mariadb
		echo "MARIADB: Client package $MARIA_PKG specified" >> "$CONFDIR/txt/install-log.txt"
	  fi
	  ;;	  
  ARCH|VOID)
	  MARIA_PKG=mariadb
	  echo "MARIADB: universal package specified" >> "$CONFDIR/txt/install-log.txt"	  
	  ;;
  MACOS)
	  # For macOS, we have different packages depending on whether Homebrew or Macports
	  # is in use. Macports makes a distinction between server and client packages;
	  # but Homebrew does not
	  if [[ $pkgmanager == "macports" ]]; then
		if [[ $GIOSERVER == "yes" ]]; then
		  MARIA_PKG=mariadb-11.4-server
		  echo "SMARIADB: erver package $MARIA_PKG specified" >> "$CONFDIR/txt/install-log.txt"
		else
		  MARIA_PKG=mariadb-11.4
		  echo "MARIADB: Client package $MARIA_PKG specified" >> "$CONFDIR/txt/install-log.txt"
		fi		  
	  elif [[ $pkgmanager == "homebrew" ]]; then
		# MacOS is a bit of a mess, to be honest, in respect of installing MariaDB via Homebrew.
		# Sequoia (15.x) and Tahoe (26.x) install MariaDB just fine
		# Sonoma (14.x) is known to require two extra packages that have to be compiled from
		# source.
		MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)

		if [[ $MACOS_MAJOR -lt 15 ]]; then
		  brew install --quiet --build-from-source groonga simdjson >/dev/null 2>&1
		fi

		# And now those dependencies are dealt with, the base MariaDB package should
		# install correctly		
		MARIA_PKG=mariadb@11.4
		echo "MARIADB: Package $MARIA_PKG specified" >> "$CONFDIR/txt/install-log.txt"	  
	  fi
	  ;;
esac
}

function initialise_db {	
if [[ $GIOSERVER == "yes" ]]; then
	
  # Determine this machine's IPv4 address and subnet mask
  if [[ $OS == "DARWIN" ]]; then
    NETIF=$(route get default | awk '/interface:/{print $2}')
    IPADDR=$(ipconfig getifaddr "$NETIF")
    NETMASK=$(ipconfig getoption "$NETIF" subnet_mask)
  else
    NETIF=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    IPADDR=$(ip -4 addr show "$NETIF" | awk '/inet / {print $2; exit}' | cut -d/ -f1)
    CIDR=$(ip -4 addr show "$NETIF" | awk '/inet / {print $2; exit}' | cut -d/ -f2)

    MASK=$(( 0xFFFFFFFF << (32-CIDR) & 0xFFFFFFFF ))
    NETMASK="$((MASK>>24&255)).$((MASK>>16&255)).$((MASK>>8&255)).$((MASK&255))"
  fi
  
  IFS=. read -r i1 i2 i3 i4 <<< "$IPADDR"
  IFS=. read -r m1 m2 m3 m4 <<< "$NETMASK"
  
  NETWORK="$((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$((i4 & m4))"
  	
  if sudo mariadb -e "use giocoso4" 2>/dev/null; then    
    :  # If giocoso4 is present, there's no need to configure/initialise MariaDB: it already has been
  else    
    # Which configuration file specifies bind address?
    MYCNF=$(mysqld --verbose --help 2>/dev/null | awk '/Default options are read from the following files/{getline; print $1; exit}')
  
    # Now determine if a bind-address is already set in that file. If yes, leave it alone. If not, append one.
	# If we append, we set it to 0.0.0.0, meaning 'listen for any connection requests coming from any and all
	# network interfaces.
    if ! grep -qE '^[[:space:]]*bind-address[[:space:]]*=' "$MYCNF" 2>/dev/null; then
      echo "" | sudo tee -a "$MYCNF" >/dev/null
      echo "[mysqld]" | sudo tee -a "$MYCNF" >/dev/null
      echo "bind-address = 0.0.0.0" | sudo tee -a "$MYCNF" >/dev/null
    fi
  
    if [[ $OS == "DARWIN" && $pkgmanager == "homebrew" ]]; then
      brew services restart mariadb@11.4 2>/dev/null
      # Now initialise the database
	  sudo mariadb >/dev/null 2>&1 <<'EOF' 
	  DELETE FROM mysql.global_priv
	  WHERE User='';

	  DELETE FROM mysql.global_priv
	  WHERE User='root'
	  AND Host NOT IN ('localhost', '127.0.0.1', '::1');

	  DROP DATABASE IF EXISTS test;

	  DELETE FROM mysql.db
	  WHERE Db='test'
	  OR Db LIKE 'test\_%';

	  FLUSH PRIVILEGES;
EOF
    elif [[ $OS == "DARWIN" && $pkgmanager == "macports" ]]; then
	  echo "skip-networking=0" | sudo tee -a "$MYCNF" >/dev/null 2>&1
  	  prefix="/opt/local"
  	  sudo mkdir -p ${prefix}/var/db/mariadb-11.4 >/dev/null 2>&1
  	  sudo chown _mysql:_mysql ${prefix}/var/db/mariadb-11.4 >/dev/null 2>&1
      (cd /tmp && sudo -u _mysql ${prefix}/lib/mariadb-11.4/bin/mariadb-install-db >/dev/null 2>&1)
	  sudo port unload mariadb-11.4-server >/dev/null 2>&1
      sudo port load mariadb-11.4-server >/dev/null 2>&1
	  sudo ln -sf "/opt/local/bin/mysql" "/opt/local/bin/mariadb" >/dev/null 2>&1>/dev/null 2>&1
	  
	  until sudo mariadb -e "select 1;" >/dev/null 2>&1; do
		  echo "Sleeping 1" >/dev/null 2>&1
		sleep 1
	  done
	  
	  sudo mariadb >/dev/null 2>&1 <<'EOF' 
	  DELETE FROM mysql.global_priv
	  WHERE User='';

	  DELETE FROM mysql.global_priv
	  WHERE User='root'
	  AND Host NOT IN ('localhost', '127.0.0.1', '::1');

	  DROP DATABASE IF EXISTS test;

	  DELETE FROM mysql.db
	  WHERE Db='test'
	  OR Db LIKE 'test\_%';

	  FLUSH PRIVILEGES;
EOF
    else
      sudo systemctl restart mariadb.service
      # Now initialise the database
	  sudo mariadb >/dev/null 2>&1 <<'EOF' 
	  DELETE FROM mysql.global_priv
	  WHERE User='';

	  DELETE FROM mysql.global_priv
	  WHERE User='root'
	  AND Host NOT IN ('localhost', '127.0.0.1', '::1');

	  DROP DATABASE IF EXISTS test;

	  DELETE FROM mysql.db
	  WHERE Db='test'
	  OR Db LIKE 'test\_%';

	  FLUSH PRIVILEGES;
EOF
    fi
  fi
fi
}

function create_db {
if [[ $GIOSERVER == "yes" ]]; then
  # Create the giocoso4 database and user, provided it doesn't already exist  
  if ! sudo mariadb -e "use giocoso4" 2>/dev/null; then
    sudo mariadb -e  "create database giocoso4 character set = 'utf8mb4' collate = 'utf8mb4_general_ci'"
    sudo mariadb -e  "create user 'giocoso4'@'localhost' identified by 'giocoso4'"
    sudo mariadb -e  "create user 'giocoso4'@'$NETWORK/$NETMASK' identified by 'giocoso4'"
    sudo mariadb -e  "grant all on *.* to 'giocoso4'@'localhost'"
    sudo mariadb -e  "grant all on *.* to 'giocoso4'@'$NETWORK/$NETMASK'"
    sudo mariadb -e  "flush privileges"
  fi

  # Now create the table structures
  # global_plays
  "${PROCONN[@]}" -e "create table if not exists global_plays (playhashvalue varchar(128) not null primary key, rechashvalue varchar(128), playdate varchar(64), foldername varchar(512), composer varchar(256), composition varchar(512), genre varchar(64), performer varchar(256), duration time, devicename varchar(64), os_type varchar(64))"  1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create index if not exists idx_gp_playdate on global_plays(playdate)"  1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create index if not exists idx_gp_composer on global_plays(composer)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create index if not exists idx_gp_rechash on global_plays(rechashvalue)" 1>&2 2>/dev/null

  # global_recordings
  "${PROCONN[@]}" -e "create table if not exists global_recordings (rechashvalue varchar(128) not null primary key, filesuffix varchar(1024), composer varchar(256), composition varchar(512), genre varchar(64), comment mediumtext, performer varchar(256), duration decimal(15,6))" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create index if not exists idx_gr_rechash on global_recordings(rechashvalue)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create index if not exists idx_gr_composer on global_recordings(composer)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create index if not exists idx_gr_composition on global_recordings(composition)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create index if not exists idx_gr_genre on global_recordings(genre)" 1>&2 2>/dev/null

  # global_notes
  "${PROCONN[@]}" -e "create table if not exists global_notes (rechashvalue varchar(128) not null primary key, notes longtext default null)" 1>&2 2>/dev/null

  # global_pauses
  "${PROCONN[@]}" -e "create table if not exists global_pauses (rechashvalue varchar(128) not null primary key, current_play_location decimal(15,6) default null)" 1>&2 2>/dev/null

  # global_phonemes
  "${PROCONN[@]}" -e "create table if not exists global_phonemes (phrase varchar(128) not null, voice varchar(32) default null, phoneme varchar(256) default null, primary key (phrase))" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create table if not exists user_phonemes (phrase varchar(128) not null, voice varchar(32) default null, phoneme varchar(256) default null, primary key (phrase))" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "drop trigger if exists trg_global_recordings_phoneme" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create trigger trg_global_recordings_phoneme after insert on global_recordings for each row insert ignore into user_phonemes (phrase) select trim(left(new.composition, char_length(new.composition) - locate('(', reverse(new.composition)))) from dual where not exists (select 1 from global_phonemes g where g.phrase = trim(left(new.composition, char_length(new.composition) - locate('(', reverse(new.composition)))))" 1>&2 2>/dev/null
  
  # Other tables
  "${PROCONN[@]}" -e "create table if not exists stored_queries (query_name varchar(64) not null primary key, query_text longtext)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create table if not exists recording_numbers (day date not null primary key, num_recordings double not null)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create table if not exists tracks (dirname text, composer text, composition text, genre text, comment text, performer text, tracknumber text, title text, duration numeric)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create table if not exists pulsesinks (identifier char(14), ipaddress text)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create table if not exists global_excludes (composer text default null, selection tinytext default null)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create table if not exists global_exempts (composer text default null, selection tinytext default null)" 1>&2 2>/dev/null

  # Some stored queries
  "${PROCONN[@]}" -e "insert into stored_queries (query_name, query_text) values ('Rarely Played Composers', 'select xxQQzQZ from global_recordings gr join (select composer from (select composer from global_plays group by composer order by date(max(playdate)) asc limit 10) as c) gp on gp.composer = gr.composer group by gr.composer');"  1>&2 2>/dev/null
  "${PROCONN[@]}" -e "insert into stored_queries (query_name, query_text) values ('Rarely Played Compositions', 'select xxQQzQZ from global_recordings gr join (select composition from (select composition from global_plays group by composition order by date(max(playdate)) asc limit 10) as c) gp on gp.composition = gr.composition group by gr.composition');"  1>&2 2>/dev/null

  # And now bunch of views
  "${PROCONN[@]}" -e "create or replace view agg_hist as select
    '1' AS Stat,
    'Less than 10 minutes' AS Description,
    sum(case when global_recordings.duration <= 600 then 1 else 0 end) AS Total,
    sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration <= 600 then 1 else 0 end) AS Played,
    sum(case when global_recordings.duration <= 600 then 1 else 0 end) - sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration <= 600 then 1 else 0 end) AS Unplayed
from
    global_recordings
union
select
    '2' AS '2',
    'Between 10 and 30 minutes' AS 'Between 10 and 30 minutes',
    sum(case when global_recordings.duration > 600 and global_recordings.duration <= 1800 then 1 else 0 end) AS Name_exp_3,
    sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration > 600 and global_recordings.duration <= 1800 then 1 else 0 end) AS Name_exp_4,
    sum(case when global_recordings.duration > 600 and global_recordings.duration <= 1800 then 1 else 0 end) - sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration > 600 and global_recordings.duration <= 1800 then 1 else 0 end) AS Name_exp_5
from
    global_recordings
union
select
    '3' AS '3',
    'Between 30 and 60 minutes' AS 'Between 30 and 60 minutes',
    sum(case when global_recordings.duration > 1800 and global_recordings.duration <= 3600 then 1 else 0 end) AS Name_exp_3,
    sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration > 1800 and global_recordings.duration <= 3600 then 1 else 0 end) AS Name_exp_4,
    sum(case when global_recordings.duration > 1800 and global_recordings.duration <= 3600 then 1 else 0 end) - sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration > 1800 and global_recordings.duration <= 3600 then 1 else 0 end) AS Name_exp_5
from
    global_recordings
union
select
    '4' AS '4',
    'Between 60 and 120 minutes' AS 'Between 60 and 120 minutes',
    sum(case when global_recordings.duration > 3600 and global_recordings.duration <= 7200 then 1 else 0 end) AS Name_exp_3,
    sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration > 3600 and global_recordings.duration <= 7200 then 1 else 0 end) AS Name_exp_4,
    sum(case when global_recordings.duration > 3600 and global_recordings.duration <= 7200 then 1 else 0 end) - sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration > 3600 and global_recordings.duration <= 7200 then 1 else 0 end) AS Name_exp_5
from
    global_recordings
union
select
    '5' AS '5',
    'Between 120 and 180 minutes' AS 'Between 120 and 180 minutes',
    sum(case when global_recordings.duration > 7200 and global_recordings.duration <= 10800 then 1 else 0 end) AS Name_exp_3,
    sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration > 7200 and global_recordings.duration <= 10800 then 1 else 0 end) AS Name_exp_4,
    sum(case when global_recordings.duration > 7200 and global_recordings.duration <= 10800 then 1 else 0 end) - sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration > 7200 and global_recordings.duration <= 10800 then 1 else 0 end) AS Name_exp_5
from
    global_recordings
union
select
    '6' AS '6',
    'Longer than 3 hours' AS 'Longer than 3 hours',
    sum(case when global_recordings.duration > 10800 then 1 else 0 end) AS Name_exp_3,
    sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration > 10800 then 1 else 0 end) AS Name_exp_4,
    sum(case when global_recordings.duration > 10800 then 1 else 0 end) - sum(case when global_recordings.rechashvalue in (select distinct global_plays.rechashvalue from global_plays) and global_recordings.duration > 10800 then 1 else 0 end) AS Name_exp_5
from
    global_recordings
order by
    1;" 1>&2 2>/dev/null

  "${PROCONN[@]}" -e "create or replace view phonemes as select phrase, voice, phoneme from user_phonemes union all select g.phrase, g.voice, g.phoneme from global_phonemes g where not exists (select 1 from user_phonemes u where u.phrase = g.phrase)"
  "${PROCONN[@]}" -e "create or replace view duration_in_secs as (select composer, substr(duration, 1,2)*3600 + substr(duration, 4,2)*60 + substr(duration, 7,2) as duration_secs from global_plays)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create or replace view total_durations as (select sum(duration_secs) as totalcount from duration_in_secs)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create or replace view composer_durations as (select composer, sum(duration_secs) as composertime from duration_in_secs group by composer)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create or replace view percentages as (select c.composer, c.composertime, t.totalcount, cast(c.composertime as float) / t.totalcount * 100 as playpercentage from total_durations t, composer_durations c)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create or replace view threshold as (select cast(1 as float)/(select count(distinct composer) from global_recordings)*100 as threshold_value)" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create or replace view notes as select gr.rechashvalue, gr.composer as Composer, gr.composition as Composition, gn.notes as Long_Notes from global_notes gn, global_recordings gr where gr.rechashvalue=gn.rechashvalue" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create or replace view composition_partitions as select rank() over (partition by composer order by rand()) as ranking, composer, filesuffix, duration, rechashvalue from global_recordings order by composer, ranking" 1>&2 2>/dev/null
  "${PROCONN[@]}" -e "create view composer_daysago as select composer, datediff(curdate(), date(max(playdate))) as DaysAgo from global_plays group by composer" 1>&2 2>/dev/null  
  "${PROCONN[@]}" -e "create or replace view underplayed_composers as with base as (select composer, datediff(curdate(), date(max(playdate))) as LPN from global_plays group by composer), ranked as (select composer, LPN, row_number() over (order by LPN desc) as rn, count(*) over () as total_composers from base) select composer, lpn from ranked where rn<=ceil(total_composers*.03)" 1>&2 2>/dev/null

  "${PROCONN[@]}" -e "create or replace view agg_stats as select 1 as 'Statnum', 'Unique Composers' as 'Statdesc', count(distinct composer) as 'Count' from global_recordings union
    select 2, 'Recordings in collection', count(*) from global_recordings union
    select 3, 'Total play-length (in days)', round(sum(duration)/86400,2) from global_recordings union
    select 5, 'Number of recordings not yet played', count(*) from global_recordings where rechashvalue not in (select distinct rechashvalue from global_plays) union
    select 4, 'Number of recordings played', count(*) from global_plays union
    select 6, 'Proportion of recordings not yet played', concat(round(np.unplayed/r.totalrecs*100,2),'%') from
    (select cast(count(*) as float) as unplayed
    from global_recordings where rechashvalue not in (select distinct rechashvalue from global_plays)) np,
    (select count(*) as totalrecs from global_recordings) r union 
    select 7, 'Average days since a composer was last played', round(avg(lpn),1) from (select composer, datediff(curdate(), date(max(playdate))) as lpn from global_plays group by composer) base union
	select 8, 'Average days since a recording was last played', round(avg(datediff(now(), max_playdate)),2) from (select p.rechashvalue, max(p.playdate) AS max_playdate from global_plays p inner join global_recordings r on p.rechashvalue = r.rechashvalue group by p.rechashvalue) as x union
	select 9, 'Average listening hours per day (last 30 days)', round(avg(daily_seconds)/3600,2) from (select date(p.playdate) as playday, sum(r.duration) as daily_seconds from global_plays p join global_recordings r on p.rechashvalue=r.rechashvalue where p.playdate >= curdate() - interval 29 day group by date(p.playdate)) x
    order by 1" 1>&2 2>/dev/null
fi
}

# Start by checking what operating system we're dealing with, unless we've
# been told explicitly as part of installer invocation
# -----------------------------------------------------------------------------
if [[ -z $GIODISTRO ]]; then
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    THISVER=$VERSION
  else
    OS=$(uname -s)
    THISVER=$(uname -r)
  fi
  OS=${OS^^}
else
  OS=${GIODISTRO^^}
fi

if hash nproc 2>/dev/null; then
  THREADS=$(nproc)
else
  THREADS=$(sysctl -n hw.logicalcpu)
fi

# Put OS into appropriate family:
# -----------------------------------------------------------------------------
if [[ $OS == *"DARWIN"* ]]; then OSFAMILY="MACOS"; fi
if [[ $OS == *"ARCH"* ]]; then OSFAMILY="ARCH"; fi
if [[ $OS == *"VOID"* ]]; then OSFAMILY="VOID"; fi
if [[ $OS == *"ALMA"* ]]; then OSFAMILY="RHEL"; fi
if [[ $OS == *"ROCKY"* ]]; then OSFAMILY="RHEL"; fi
if [[ $OS == *"FEDORA"* ]]; then OSFAMILY="FEDORA"; fi
if [[ $OS == *"DEBIAN"* ]]; then OSFAMILY="DEBIAN"; fi
if [[ $OS == *"UBUNTU"* ]]; then OSFAMILY="UBUNTU"; fi
if [[ -z $OSFAMILY ]]; then OSFAMILY="ELSE"; fi

# Raspberry Pi is different from vanilla Debian, in how you determine the specifics
# -----------------------------------------------------------------------------
if [[ -f /etc/rpi-issue ]]; then OSFAMILY="RASPBIAN"; fi

# Now define the software tools etc. required for each family
# -----------------------------------------------------------------------------
case $OSFAMILY in
  VOID)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f gio4inst; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Giocoso installer ready. Please bear with us for a few moments..."
    sudo xbps-install -Sy >/dev/null 2>&1

    if sudo xbps-install -un | grep -q .; then
      pending=1
      check_updates
    fi
    
    sudo xbps-install -Sfy dialog > /dev/null 2>&1
    determine_role
	
    # Define what's required
    packages=(alsa-utils base-devel bc curl espeak-ng fd file fmt fontconfig gawk git grep nano ncurses util-linux w3m wezterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo xbps-install -Sf -y "$pkg" >> "$CONFDIR/txt/install-log.txt" 2>&1 || true
      sleep 0.1
    done
    ) | dialog --title " Installing Giocoso's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70

	maria_components
	sudo xbps-install -Sf -y "$MARIA_PKG" >> "$CONFDIR/txt/install-log.txt" 2>&1
    initialise_db
    create_db
    
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Giocoso's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fd
  ;;
  
  ARCH)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f gio4inst; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Giocoso installer ready. Please bear with us for a few moments..."
    sudo pacman --noconfirm -Syy >/dev/null 2>&1

    if sudo pacman -Qu | grep -q .; then
      pending=1
      check_updates
    fi

    sudo pacman -S --noconfirm dialog > /dev/null 2>&1
    determine_role
    # Define what's required
    packages=(alsa-utils base-devel bc cmake curl espeak-ng fd file fmt fontconfig gawk git grep nano ncurses util-linux w3m wezterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo pacman -S --noconfirm "$pkg"  >> "$CONFDIR/txt/install-log.txt" 2>&1  || true
      sleep 0.1
    done
    ) | dialog --title " Installing Giocoso's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70

	maria_components
	sudo pacman -S --noconfirm "$MARIA_PKG"  >> "$CONFDIR/txt/install-log.txt" 2>&1 
	initialise_db
	create_db
	
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Giocoso's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fd
  ;;

  DEBIAN)
  if [[ $CHECKONLY -eq 0 ]]; then
    # If sudo doesn't work, grant the user SUDO privileges. Otherwise, just get on with it...
    if ! sudo -n true 2>/dev/null; then
      tput cup 8 4; tput setaf $INFOTEXT; echo -en "Please supply the "; tput setaf $ALERT; echo -en "\e[4mroot user\e[24m"; tput setaf $INFOTEXT; echo -en " password when prompted. "
      su -c "
      echo \"$USER ALL=(ALL:ALL) ALL\" >/etc/sudoers.d/$USER
      chmod 440 /etc/sudoers.d/$USER
      "
    fi

    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Now supply the sudo password for user %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f gio4inst; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Giocoso installer ready. Please bear with us for a few moments..."
    wget -qO- https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    sudo apt-get update -qq
    pending=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')
    check_updates

    sudo apt-get -y install dialog > /dev/null 2>&1
    determine_role
	
    # Define what's required
    packages=(alsa-utils bc coreutils curl espeak-ng fd-find file fontconfig gawk grep libncurses6 nano uuid-runtime w3m wezterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo apt-get -y install "$pkg"  >> "$CONFDIR/txt/install-log.txt" 2>&1  || true
      sleep 0.1
    done
    ) | dialog --title " Installing Giocoso's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70

	maria_components
	sudo apt-get -y install "$MARIA_PKG"  >> "$CONFDIR/txt/install-log.txt" 2>&1 
	initialise_db
    create_db
    
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Giocoso's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fdfind
  ;;

  RASPBIAN)
  if [[ $CHECKONLY -eq 0 ]]; then
    # If sudo doesn't work, grant the user SUDO privileges. Otherwise, just get on with it...
    if ! sudo -n true 2>/dev/null; then
      tput cup 8 4; tput setaf $INFOTEXT; echo -en "Please supply the "; tput setaf $ALERT; echo -en "\e[4mroot user\e[24m"; tput setaf $INFOTEXT; echo -en " password when prompted. "
      su -c "
      echo \"$USER ALL=(ALL:ALL) ALL\" >/etc/sudoers.d/$USER
      chmod 440 /etc/sudoers.d/$USER
      "
    fi

    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Now supply the sudo password for user %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f gio4inst; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Giocoso installer ready. Please bear with us for a few moments..."
    sudo apt-get update -qq
    pending=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')
    check_updates
    
    sudo apt-get -y install dialog > /dev/null 2>&1
    determine_role
	
    # Define what's required
    packages=(alsa-utils bc coreutils curl espeak-ng fd-find file fontconfig gawk grep libncurses6 nano uuid-runtime w3m)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo apt-get -y install "$pkg"  >> "$CONFDIR/txt/install-log.txt" 2>&1  || true
      sleep 0.1
    done
    ) | dialog --title " Installing Giocoso's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
	maria_components
	sudo apt-get -y install "$MARIA_PKG"  >> "$CONFDIR/txt/install-log.txt" 2>&1
	initialise_db
	create_db
	
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Giocoso's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fdfind
  ;;

  UBUNTU)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f gio4inst; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Giocoso installer ready. Please bear with us for a few moments..."
    wget -qO- https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list > /dev/null
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    sudo apt-get update -qq
    pending=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')
    check_updates

    sudo apt-get -y install dialog > /dev/null 2>&1
    determine_role
	
    # Define what's required
    packages=(alsa-utils bc coreutils curl espeak-ng fd-find file fontconfig gawk grep libncurses6 nano uuid-runtime w3m wezterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo apt-get -y install "$pkg"  >> "$CONFDIR/txt/install-log.txt" 2>&1  || true
      sleep 0.1
    done
    ) | dialog --title " Installing Giocoso's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
	maria_components
	sudo apt-get -y install "$MARIA_PKG"  >> "$CONFDIR/txt/install-log.txt" 2>&1 
	initialise_db
	create_db
	
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Giocoso's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep SEDPROG=sed DATEPROG=date MD5PROG=md5sum FDPROG=fdfind
  ;;

  FEDORA)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f gio4inst; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Giocoso installer ready. Please bear with us for a few moments..."
    sudo dnf copr enable -y -q wezfurlong/wezterm-nightly >/dev/null 2>&1
    sudo dnf check-update --refresh -q; rc=$?
    
    if [[ $rc -eq 100 ]]; then
      pending=1
      check_updates
    fi

    echo "    Adding needed repositories. Please be patient..."
    sudo dnf -y install dialog > /dev/null 2>&1
    sudo dnf -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm >/dev/null 2>&1
    sudo dnf -y copr enable lchh/libsixel > /dev/null 2>&1
    determine_role
	
    # Define what's required
    packages=(alsa-utils bc coreutils curl espeak-ng fd-find file fontconfig gawk grep nano ncurses util-linux w3m wezterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo dnf -y install "$pkg" --allowerasing  >> "$CONFDIR/txt/install-log.txt" 2>&1  || true
      sleep 0.1
    done
    ) | dialog --title " Installing Giocoso's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70

	maria_components
	sudo dnf -y install "$MARIA_PKG" --allowerasing  >> "$CONFDIR/txt/install-log.txt" 2>&1 
	initialise_db
	create_db
	
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Giocoso's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum FDPROG=fd
  ;;

  RHEL)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f gio4inst; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Giocoso installer ready. Please bear with us for a few moments..."
    sudo dnf copr enable -y -q wezfurlong/wezterm-nightly rhel-9-x86_64 >/dev/null 2>&1
    sudo dnf check-update --refresh -q; rc=$?
    
    if [[ $rc -eq 100 ]]; then
      pending=1
      check_updates
    fi

    echo "    Adding needed repositories. Please be patient..."
    sudo dnf -y install dialog > /dev/null 2>&1
    determine_role
		
    FUSIONON=$(sudo dnf repolist | grep epel | wc -l)
    if [[ $FUSIONON -eq 0 ]]; then
      sudo dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf -y install "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf -y install "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf config-manager --add-repo=https://negativo17.org/repos/epel-multimedia.repo >/dev/null 2>&1
      sudo dnf -y config-manager --set-enabled crb >/dev/null 2>&1
    fi

    # Define what's required
    packages=(alsa-utils bc coreutils curl espeak-ng fd-find file fontconfig gawk grep nano ncurses util-linux w3m wezterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo dnf -y install "$pkg" --allowerasing  >> "$CONFDIR/txt/install-log.txt" 2>&1  || true
      sleep 0.1
    done
    ) | dialog --title " Installing Giocoso's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70

	maria_components
	sudo dnf -y install "$MARIA_PKG" --allowerasing  >> "$CONFDIR/txt/install-log.txt" 2>&1 
	initialise_db
    create_db
    
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Giocoso's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum FDPROG=fd
  ;;

  MACOS)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f gio4inst; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    echo ""
    echo "    Getting the Giocoso installer ready. Please bear with us for a few moments..."
    echo ""

    # Create a destination folder for Giocoso
    if [[ ! -d /usr/local/bin ]]; then
      sudo mkdir -p /usr/local/bin
      sudo chown -R $(whoami) /usr/local/bin
      sudo chmod -R u=rwX,go=rX /usr/local/bin
    fi
    
     while true; do
      echo "    Do you want to use Homebrew (h) or Macports (m) as your package installer?"
      echo "    Note that whatever you choose here must have already been installed by you, manually."
      echo "    Do not mix package installers: if you've already used one or the other, stick"
      echo "    to that one now. If you have a free choice, choose Macports for older machines"
      echo "    and for the fact that it's *much* faster to complete!"
      echo ""
      read -n 1 -p "    Homebrew or Macports, then? (h/m): " input
      case "$input" in
       [hH])
         if command -v brew >/dev/null 2>&1; then
           pkgmanager=homebrew
           echo ""
           echo "    Using the Homebrew Package Manager. Please hold on..."
           echo ""
           brew install --quiet dialog >/dev/null 2>&1
           break
         else
           echo ""
           echo "    Unfortunately, it appears that Homebrew has not already been installed on this system."
           echo "    Do that first, manually, before trying to re-run this installer."
           echo ""
           exit 1        
         fi  
         ;;
       [mM])
         if command -v port >/dev/null 2>&1; then
           pkgmanager=macports
           echo ""
           echo "    Using the Macports Package Manager. Please wait..."
           echo ""
           sudo port -N install dialog > /dev/null 2>&1           
           break
         else
           echo ""
           echo "    Unfortunately, it appears that Macports has not already been installed on this system."
           echo "    Do that first, manually, before trying to re-run this installer."
           echo ""
           exit 1
         fi   
         ;;
       *)
         clear
         echo ""
         echo "    Invalid input: only h or m are allowed. Please try again."
         echo ""
        ;;
      esac
    done
	
    determine_role

    # Define what's required
    packages=(bc coreutils fd file fontconfig gawk gsed ggrep grep md5sha1sum ncurses nano util-linux w3m wezterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      if [[ $pkgmanager == "homebrew" ]]; then
        brew install --quiet "$pkg"  >> "$CONFDIR/txt/install-log.txt" 2>&1 
      elif [[ $pkgmanager == "macports" ]]; then
        sudo port -N install "$pkg"  >> "$CONFDIR/txt/install-log.txt" 2>&1 
      fi
      
      sleep 0.1
    done
    ) | dialog --title " Installing Giocoso's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient...\nPress no keys until prompted!!" 12 70

	maria_components
    if [[ $pkgmanager == "homebrew" ]]; then
      brew install --quiet "$MARIA_PKG"  >> "$CONFDIR/txt/install-log.txt" 2>&1 
    elif [[ $pkgmanager == "macports" ]]; then
      sudo port -N install "$MARIA_PKG"  >> "$CONFDIR/txt/install-log.txt" 2>&1 
	  sudo port select mysql mariadb-11.4  >> "$CONFDIR/txt/install-log.txt" 2>&1 
    fi
    initialise_db
    create_db
    
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Giocoso's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=ggrep  SEDPROG=gsed  DATEPROG=gdate  MD5PROG=md5sum  FDPROG=fd
  ;;
  
  *)
  echo "Sorry, but you are using an unsupported operating system. I cannot proceed, so quitting!"
  exit 1
  ;;
esac

# Almost finally, determine whether we're on macOS or Linux, and x86_64 or arm 
# architecture and then construct executable paths and names from that
# -----------------------------------------------------------------------------
case "$(uname -s)" in
    Darwin) OS_PLATFORM="macos" ;;
    Linux)  OS_PLATFORM="linux" ;;
    *)      OS_PLATFORM="unknown" ;;
esac

case "$(uname -m)" in
    arm64|aarch64) OS_ARCHITECTURE="arm64" ;;
    x86_64)        OS_ARCHITECTURE="x86_64" ;;
    *)             OS_ARCHITECTURE="unknown" ;;
esac

FFMPEG="$CONFDIR/exec/ffmpeg-${OS_PLATFORM}-${OS_ARCHITECTURE}"
FFPROBE="$CONFDIR/exec/ffprobe-${OS_PLATFORM}-${OS_ARCHITECTURE}"
FLAC="$CONFDIR/exec/flac-${OS_PLATFORM}-${OS_ARCHITECTURE}"
METAFLAC="$CONFDIR/exec/metaflac-${OS_PLATFORM}-${OS_ARCHITECTURE}"
MAGICK="$CONFDIR/exec/magick-${OS_PLATFORM}-${OS_ARCHITECTURE}"
SIXEL="$CONFDIR/exec/img2sixel-${OS_PLATFORM}-${OS_ARCHITECTURE}"

# Write all variables to a file and export the Magic Configure Path
# -----------------------------------------------------------------------------
echo "SEDPROG=$SEDPROG
GREPPROG=$GREPPROG
DATEPROG=$DATEPROG
MD5PROG=$MD5PROG
FDPROG=$FDPROG
FFMPEG=$FFMPEG
FFPROBE=$FFPROBE
FLAC=$FLAC
METAFLAC=$METAFLAC
MAGICK=$MAGICK
SIXEL=$SIXEL
export MAGICK_CONFIGURE_PATH=$CONFDIR/txt" > "$CONFDIR/txt/programvariables.txt"
