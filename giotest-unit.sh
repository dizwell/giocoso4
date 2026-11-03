#!/usr/bin/env bash
# ====================================================================================================
# giotest-unit.sh: Layer 2 test harness for Giocoso. Unit tests of the self-contained helper functions.
#
# It never starts Giocoso, never touches a database, never plays anything. Each function is lifted
# out of the real script that defines it (from "function name {" to the first "}" in column 1), so
# the tests exercise the code you actually run, and none of a script's start-up code is executed.
# Tests that write files do so in a temporary folder that is removed afterwards.
#
# Usage:  giotest-unit.sh [ROOT]      (same ROOT convention as giotest-static.sh)
#
# Exit status: 0 if there are no FAILs, 1 otherwise.
# ====================================================================================================
ROOT="${1:-$HOME/.local/share/giocoso4}"
ROOT="${ROOT%/}"
FAILS=0; PASSES=0; SKIPS=0

if [[ ! -d $ROOT ]]; then echo "No such folder: $ROOT"; exit 2; fi
if [[ -d $ROOT/bin ]]; then BIN="$ROOT/bin"; else BIN="$ROOT"; fi

# GNU tools if installed (macOS), plain ones otherwise; the scripts themselves use these names.
GREPPROG=$(command -v ggrep || command -v grep)
SEDPROG=$(command -v gsed || command -v sed)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/giounit.XXXXXX"); trap 'rm -rf "$TMP"' EXIT

function heading { echo; echo "== $1"; }
function pass { PASSES=$((PASSES + 1)); echo "  PASS  $1"; }
function skip { SKIPS=$((SKIPS + 1)); echo "  SKIP  $1"; }
function fail {
  FAILS=$((FAILS + 1)); echo "  FAIL  $1"
  shift; for line in "$@"; do echo "          $line"; done
}

# check "description" "expected" "actual"
function check {
  if [[ $2 == "$3" ]]; then
    pass "$1"
  else
    fail "$1" "expected: [$2]" "     got: [$3]"
  fi
}

# load_fn NAME FILE: define function NAME from FILE in this shell. Returns 1 if it can't be found.
function load_fn {
  local name="$1" file="$BIN/$2" body
  if [[ ! -f $file ]]; then fail "$name: $2 not found"; return 1; fi
  body=$($SEDPROG -n "/^function $name {/,/^}/p" "$file")
  if [[ -z $body ]]; then fail "$name: not found in $2 (as 'function $name {' with its closing } in column 1)"; return 1; fi
  eval "$body" 2>"$TMP/evalerr" || { fail "$name: could not be defined" "$(cat "$TMP/evalerr")"; return 1; }
}

# footer_line builds its text with backslash sequences (printed later with echo -e), so FOOTER holds the
# characters  \033[7m  rather than a real escape character. These are what we look for.
RV='\033[7m'; OFF='\033[0m'

# Remove the colour/reverse-video escape codes so we can compare the visible text
function plain {
  local s
  shopt -s extglob
  s=$(printf '%b' "$1")
  printf '%s' "${s//$'\033'\[*([0-9;])m/}"
}

# ----------------------------------------------------------------------------------------------------
heading "1. gbasename and gdirname (giofunctions.sh)"
if load_fn gbasename giofunctions.sh && load_fn gdirname giofunctions.sh; then
  check "gbasename /a/b/c.flac"           "c.flac"        "$(gbasename /a/b/c.flac)"
  check "gbasename trailing slash"         "b"             "$(gbasename /a/b/)"
  check "gbasename with spaces"            "My File.flac"  "$(gbasename "/Music/My File.flac")"
  check "gbasename of a bare name"         "x.flac"        "$(gbasename x.flac)"
  check "gdirname /a/b/c.flac"             "/a/b"          "$(gdirname /a/b/c.flac)"
  check "gdirname trailing slash"          "/a"            "$(gdirname /a/b/)"
  check "gdirname with spaces"             "/Music/My Dir" "$(gdirname "/Music/My Dir/x.flac")"
  # Agreement with the real programs, for ordinary paths
  for p in /usr/lib/x.so "/tmp/a b/c d.txt" /x/y/z/; do
    check "gbasename agrees with basename: $p" "$(basename "$p")" "$(gbasename "$p")"
    check "gdirname agrees with dirname: $p"   "$(dirname "$p")"  "$(gdirname "$p")"
  done
fi

# ----------------------------------------------------------------------------------------------------
heading "2. round (giofunctions.sh)"
if load_fn round giofunctions.sh; then
  if command -v bc >/dev/null 2>&1; then
    check "round 2.345 to 2 places"   "2.35" "$(round 2.345 2)"
    check "round 2.344 to 2 places"   "2.34" "$(round 2.344 2)"
    check "round 7 to 0 places"       "7"    "$(round 7 0)"
    check "round 0.5 to 0 places"     "1"    "$(round 0.5 0)"
    check "round 99.999 to 1 place"   "100.0" "$(round 99.999 1)"
  else
    skip "round: bc is not installed"
  fi
fi

# ----------------------------------------------------------------------------------------------------
heading "3. convert_to_secs and convert_from_secs (giocount.sh)"
if load_fn convert_to_secs giocount.sh; then
  # Each call runs in its own subshell, so that an arithmetic error is reported as a failed test
  # (with the error text as the "got" value) instead of silently ending the whole section.
  function cts { ( convert_to_secs "$1"; printf '%s' "$REPLY" ) 2>&1; }
  check "00:01:14 is 74 seconds"                 "74"    "$(cts 00:01:14)"
  check "00:00:00 is 0"                 "0" "$(cts "00:00:00")"
  check "01:00:00 is 3600"              "3600" "$(cts "01:00:00")"
  check "10:30:15 is 37815"             "37815" "$(cts "10:30:15")"
  check "08:09:09 (the octal trap)"     "29349" "$(cts "08:09:09")"
  check "00:08:08 (the octal trap)"     "488" "$(cts "00:08:08")"
  check "leading spaces are ignored"    "5" "$(cts "  00:00:05")"
  check "fractions of a second ignored" "74" "$(cts "00:01:14.56")"
  check "N/A gives 0"                   "0" "$(cts "N/A")"
  check "Video gives 0"                 "0" "$(cts "Video")"
  check "empty gives 0"                 "0" "$(cts "")"
  check "mm:ss only gives 0"            "0" "$(cts "12:34")"
fi
if load_fn convert_from_secs giocount.sh; then
  check "0 seconds"            "00:00:00" "$(convert_from_secs 0)"
  check "74 seconds"           "00:01:14" "$(convert_from_secs 74)"
  check "3600 seconds"         "01:00:00" "$(convert_from_secs 3600)"
  check "86399 seconds"        "23:59:59" "$(convert_from_secs 86399)"
  check "90000 seconds"        "25:00:00" "$(convert_from_secs 90000)"
  # Round trip: converting back and forth must give the same number
  if declare -f convert_to_secs >/dev/null; then
    bad=""
    for n in 0 1 59 60 61 3599 3600 3661 7322 45296 86399; do
      t=$(convert_from_secs $n); r=$(cts "$t")
      [[ $r == "$n" ]] || bad+=" $n->$t->$r"
    done
    check "round trip seconds -> hh:mm:ss -> seconds" "" "$bad"
  fi
fi

# ----------------------------------------------------------------------------------------------------
heading "4. footer_line (giofunctions.sh)"
if load_fn footer_line giofunctions.sh; then
  DIRECT_PLAY=0; footer_line
  check "full player, nothing active" \
        "Autostop     Terminate     Pause     Skip     Repeat     Notes     Exit" "$(plain "$FOOTER")"
  [[ $FOOTER != *"$RV"* ]] && pass "full player: nothing in reverse video" || fail "full player: nothing should be in reverse video"
  footer_line Skip
  check "Skip active: visible text unchanged" \
        "Autostop     Terminate     Pause     Skip     Repeat     Notes     Exit" "$(plain "$FOOTER")"
  [[ $FOOTER == *"${RV}Skip${OFF}"* ]] && pass "Skip is in reverse video" || fail "Skip should be in reverse video"
  hl=${FOOTER//"$RV"/@}; hl=${hl//[^@]/}
  check "exactly one word highlighted" "1" "${#hl}"
  footer_line Autostop Repeat
  hl=${FOOTER//"$RV"/@}; hl=${hl//[^@]/}
  check "two words active, two highlighted" "2" "${#hl}"
  [[ $FOOTER == *"${RV}Autostop${OFF}"* && $FOOTER == *"${RV}Repeat${OFF}"* ]] \
    && pass "Autostop and Repeat are in reverse video" || fail "Autostop and Repeat should be in reverse video"
  footer_line Skip
  [[ $FOOTER == *"E"*$'x'* ]] && pass "Exit keeps its hotkey letter" || fail "Exit lost its hotkey letter"
  DIRECT_PLAY=1; footer_line
  check "minig: four items only" "Autostop     Terminate     Skip     Repeat" "$(plain "$FOOTER")"
  footer_line Terminate
  [[ $FOOTER == *"${RV}Terminate${OFF}"* ]] && pass "minig: Terminate in reverse video" || fail "minig: Terminate should be in reverse video"
  DIRECT_PLAY=0
fi

# ----------------------------------------------------------------------------------------------------
heading "5. Config file: write, then read back (gioconfconstruct.sh)"
if load_fn conf_text gioconfconstruct.sh && load_fn create_conf gioconfconstruct.sh; then
  CONFDIR="$TMP/conf"; mkdir -p "$CONFDIR/txt"
  CONFFILE="$CONFDIR/txt/giocoso.conf"
  CANARY="$TMP/canary"

  function set_defaults {
    CONFDEVICE="default"; CONFDURATIONS="hours"; CONFBACKUPDIR="/tmp/Backups"; CONFMYSQLIP="127.0.0.1"
    CONFMYSQLPRT="3306"; CONFFILEPREFIX=""; CONFBROWZ="firefox"; CONFPULSE=""; CONFWEZTHEME="Banana Blueberry"
    CONFDIATHEME="standard"; CONFSELECTIONS=20; CONFTIMEBAR=10; CONFCOUNT=5; CONFARTSIZE=300
    CONFLOGOSIZE=30; CONFLOGOPOS=3; CONFWEZFNTSZ=16; CONFACCENTS=yes; CONFPULSEAUDIO=no; CONFRPG=yes
    CONFVOICE=no; CONFVSPEED=1
  }

  # 5a. Ordinary values with spaces: the file must source cleanly, and the values come back intact
  set_defaults; CONFBACKUPDIR="/Users/hjr/Desktop/Proof of Identity"
  create_conf
  ( source "$CONFFILE" ) 2>"$TMP/err" ; rc=$?
  check "conf sources without error" "0" "$rc"
  check "conf sources silently" "" "$(cat "$TMP/err")"
  check "BACKUP_DIR with spaces survives sourcing" "/Users/hjr/Desktop/Proof of Identity" \
        "$(source "$CONFFILE"; printf '%s' "$BACKUP_DIR")"
  check "WEZTHEME with a space survives sourcing"  "Banana Blueberry" \
        "$(source "$CONFFILE"; printf '%s' "$WEZTHEME")"
  check "numeric value survives sourcing"          "20" "$(source "$CONFFILE"; printf '%s' "$SELECTIONS")"
  check "conf_text reads BACKUP_DIR without quotes" "/Users/hjr/Desktop/Proof of Identity" "$(conf_text BACKUP_DIR)"
  check "conf_text reads DEVICE"                    "default" "$(conf_text DEVICE)"
  check "conf_text of a missing key is empty"       "" "$(conf_text NO_SUCH_KEY)"

  # 5b. A value containing '=' must not be cut short
  set_defaults; CONFBROWZ="open -a Firefox --args a=b"
  create_conf
  check "'=' inside a value is kept (conf_text)" "open -a Firefox --args a=b" "$(conf_text BROWSER)"
  check "'=' inside a value is kept (sourced)"   "open -a Firefox --args a=b" "$(source "$CONFFILE"; printf '%s' "$BROWSER")"

  # 5c. Hostile values: nothing may be executed or expanded when the file is sourced
  set_defaults
  CONFBACKUPDIR="/tmp/x\"; touch $CANARY; echo \""
  CONFPULSE='$(touch '"$CANARY"')'
  CONFFILEPREFIX='`touch '"$CANARY"'`'
  CONFWEZTHEME='Back\slash $HOME'
  create_conf
  ( source "$CONFFILE" ) >/dev/null 2>"$TMP/err"; rc=$?
  check "hostile values: conf still sources (status)" "0" "$rc"
  [[ ! -e $CANARY ]] && pass "hostile values: no command was executed" || fail "hostile values: a command embedded in a value was EXECUTED"
  hostile=$(source "$CONFFILE"; printf '%s|%s|%s' "$BACKUP_DIR" "$WEZTHEME" "$PULSESERVER")
  [[ $hostile != *'$HOME'* && $hostile != *'\'* && $hostile != *'"'* ]] \
    && pass "hostile values: quotes, \$ and backslashes were stripped" \
    || fail "hostile values: unsafe characters survived" "got: $hostile"
  rm -f "$CANARY"

  # 5d. Writing a second time keeps a backup of the first, and the final file is the new one
  set_defaults; CONFDEVICE="first"; create_conf
  CONFDEVICE="second"; create_conf
  check "second write replaces the first"   "second" "$(conf_text DEVICE)"
  n=$(ls "$CONFDIR"/txt/giocoso.conf-*.bkp 2>/dev/null | wc -l)
  [[ $n -ge 1 ]] && pass "a .bkp copy of the old config was made" || fail "no .bkp copy of the old config was made"
fi

# ----------------------------------------------------------------------------------------------------
heading "6. Notes: fetch_note and store_note (gioretnote.sh)"
if load_fn fetch_note gioretnote.sh && load_fn store_note gioretnote.sh; then
  # A stand-in for the database client: it records the arguments of a call made with -e, and the standard
  # input of one made without. Nothing is sent anywhere.
  function fakedb {
    local a
    for a in "$@"; do
      if [[ $a == "-e" ]]; then printf '%s\n' "$*" > "$TMP/db_args"; return 0; fi
    done
    cat > "$TMP/db_stdin"
  }
  PROCONN=(fakedb)
  GOODHASH=2d2f9e1882acd3aa729d985e4a8eb0ee

  # Turn a string of hex digits back into the text it stands for (bytes go to a file, so nothing is lost to $( ) )
  function unhex {
    local h="$1" i
    : > "$TMP/db_decoded"
    for ((i = 0; i < ${#h}; i += 2)); do printf "\\x${h:i:2}" >> "$TMP/db_decoded"; done
    cat "$TMP/db_decoded"
  }

  # fetch_note
  rm -f "$TMP/db_args"; RECHASHVALUE=$GOODHASH; fetch_note
  args=$(cat "$TMP/db_args" 2>/dev/null)
  [[ $args == *" -r "* ]] && pass "fetch_note asks for raw output (-r), so no \\n or \\t escaping" || fail "fetch_note does not use -r" "$args"
  [[ $args == *"select notes from global_notes where rechashvalue='$GOODHASH'"* ]] \
    && pass "fetch_note selects the note for the right hash" || fail "fetch_note SQL is not as expected" "$args"
  rm -f "$TMP/db_args"; RECHASHVALUE="x'; drop table global_notes; --"; fetch_note; rc=$?
  check "fetch_note refuses a hash that is not hex (return status)" "1" "$rc"
  [[ ! -e $TMP/db_args ]] && pass "fetch_note sent nothing to the database for a bad hash" || fail "fetch_note sent a statement for a bad hash"

  # store_note: awkward text
  NASTY=$'It\'s "q"; drop table x;\n\nback\\slash \\n \\\\ tab\there | pipe \u00e9 \u65e5\u672c `back` $HOME'
  rm -f "$TMP/db_stdin"; RECHASHVALUE=$GOODHASH; store_note "$NASTY"; rc=$?
  sql=$(cat "$TMP/db_stdin" 2>/dev/null)
  check "store_note returns success" "0" "$rc"
  [[ $sql == "replace into global_notes values ('$GOODHASH', CONVERT(UNHEX('"*"') USING utf8mb4))" ]] \
    && pass "store_note builds a replace with UNHEX" || fail "store_note SQL has an unexpected shape" "$sql"
  hex=${sql#*UNHEX(\'}; hex=${hex%%\'*}
  [[ $hex =~ ^[0-9a-f]+$ ]] && pass "the note travels as hex digits only" || fail "the hex part contains something else" "$hex"
  q=${sql//[^\']/}
  check "only four single quotes in the whole statement (hash and hex, nothing from the note)" "4" "${#q}"
  decoded=$(unhex "$hex")
  check "the hex decodes back to exactly the original text" "$NASTY" "$decoded"
  [[ $sql != *"drop table"* ]] && pass "no part of the note appears as readable SQL" || fail "note text appears in the SQL as text"

  # store_note: blank text removes the note
  for blank in "" "   " $'\n' $'  \n\n \t'; do
    rm -f "$TMP/db_stdin"; store_note "$blank"
    check "blank text ($(printf '%q' "$blank")) becomes a delete" \
          "delete from global_notes where rechashvalue='$GOODHASH'" "$(cat "$TMP/db_stdin" 2>/dev/null)"
  done

  # store_note: bad hash must send nothing
  rm -f "$TMP/db_stdin"; RECHASHVALUE="abc'; delete from global_notes; --"; store_note "hello"; rc=$?
  check "store_note refuses a hash that is not hex (return status)" "1" "$rc"
  [[ ! -e $TMP/db_stdin ]] && pass "store_note sent nothing to the database for a bad hash" || fail "store_note sent a statement for a bad hash"
  rm -f "$TMP/db_stdin"; RECHASHVALUE=""; store_note "hello"; rc=$?
  check "store_note refuses an empty hash" "1" "$rc"

  # A long note (about 20,000 characters) is no problem
  RECHASHVALUE=$GOODHASH; LONG=$(printf 'x%.0s' $(seq 1 20000))
  rm -f "$TMP/db_stdin"; store_note "$LONG"
  hex=$(sed -e "s/.*UNHEX('//" -e "s/').*//" "$TMP/db_stdin")
  check "a 20,000 character note gives 40,000 hex digits" "40000" "${#hex}"
  unset PROCONN RECHASHVALUE
fi

# ----------------------------------------------------------------------------------------------------
echo
echo "=============================================================================================="
echo "  $PASSES passed, $SKIPS skipped, $FAILS failed"
echo "=============================================================================================="
[[ $FAILS -eq 0 ]]
