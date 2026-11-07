#!/usr/bin/env bash
# ====================================================================================================
# giotest-static.sh: Layer 1 test harness for Giocoso. Static checks only: it never runs Giocoso,
# never touches a database, never plays anything. It reads the scripts and reports problems.
#
# Usage:  giotest-static.sh [ROOT]
#
# ROOT is the folder holding giocoso4.sh and giocoso-installer.sh, with the other scripts in ROOT/bin
# (the layout on a real installation: ~/.local/share/giocoso4). If ROOT has no bin folder, the scripts
# are assumed to all be in ROOT itself (the layout of a release zip). ROOT defaults to
# ~/.local/share/giocoso4.
#
# Exit status: 0 if there are no FAILs (WARNs are advisory), 1 otherwise.
# ====================================================================================================
ROOT="${1:-$HOME/.local/share/giocoso4}"
ROOT="${ROOT%/}"
FAILS=0; WARNS=0; PASSES=0

if [[ ! -d $ROOT ]]; then echo "No such folder: $ROOT"; exit 2; fi
if [[ -d $ROOT/bin ]]; then BIN="$ROOT/bin"; else BIN="$ROOT"; fi
MAIN="$ROOT/giocoso4.sh"
INSTALLER="$ROOT/giocoso-installer.sh"

# Use the GNU tools if they are installed (macOS), the plain ones otherwise.
GAWK=$(command -v gawk || command -v awk)
GREP=$(command -v ggrep || command -v grep)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/giotest.XXXXXX"); trap 'rm -rf "$TMP"' EXIT

# Every script we are testing, as one list
ALL=()
[[ -f $MAIN ]] && ALL+=("$MAIN")
[[ -f $INSTALLER ]] && ALL+=("$INSTALLER")
for f in "$BIN"/*.sh; do [[ -f $f ]] && ALL+=("$f"); done
# Both layouts can contain giocoso4.sh/installer inside BIN: de-duplicate
mapfile -t ALL < <(printf '%s\n' "${ALL[@]}" | sort -u)

function heading {
  echo; echo "== $1"
}

function pass {
  PASSES=$((PASSES + 1)); echo "  PASS  $1"
}

function warn {
  WARNS=$((WARNS + 1)); echo "  WARN  $1"
  shift; for line in "$@"; do echo "          $line"; done
}

function fail {
  FAILS=$((FAILS + 1)); echo "  FAIL  $1"
  shift; for line in "$@"; do echo "          $line"; done
}

function short {
  # Strip the ROOT prefix so lines are readable
  sed "s#^$ROOT/##"
}

# ----------------------------------------------------------------------------------------------------
# 1. Syntax: bash -n on every script
# ----------------------------------------------------------------------------------------------------
function check_syntax {
  heading "1. Syntax (bash -n)"
  local bad=() f out
  for f in "${ALL[@]}"; do
    out=$(bash -n "$f" 2>&1) || bad+=("${f#$ROOT/}: $(echo "$out" | head -1)")
  done
  if [[ ${#bad[@]} -eq 0 ]]; then pass "all ${#ALL[@]} scripts parse"; else fail "syntax errors" "${bad[@]}"; fi
}

# ----------------------------------------------------------------------------------------------------
# 2. shellcheck, with the known-and-accepted noise filtered out
# ----------------------------------------------------------------------------------------------------
function check_shellcheck {
  heading "2. shellcheck"
  if ! command -v shellcheck >/dev/null 2>&1; then
    warn "shellcheck is not installed (brew install shellcheck); skipping"; return
  fi
  local f out=() line
  # Codes ignored everywhere: unused/unassigned variables (scripts are sourced, so shellcheck cannot see
  # across files), source-following, arrays-in-prose and 'sudo ... >> file' redirects (deliberately the user's).
  local skip="SC2034,SC2154,SC1090,SC1091,SC2024,SC2086,SC2012,SC2009,SC2004,SC2155,SC2002,SC2162,SC2129,SC2115,SC2016,SC2028,SC2015,SC2181,SC2207,SC2010,SC2001,SC2003,SC2005,SC2006,SC1087,SC2220,SC2206,SC2046"
  for f in "${ALL[@]}"; do
    [[ $(basename "$f") == giotput.sh ]] && continue          # a third-party tput wrapper, not ours to fix
    while IFS= read -r line; do
      [[ -z $line ]] && continue
      out+=("$line")
    done < <(shellcheck -s bash -S warning -e "$skip" -f gcc "$f" 2>/dev/null | short)
  done
  # Accepted: 'local' at the top of giooutput.sh (always sourced from inside a function) and guarded cds
  local kept=() parse=() l
  for l in "${out[@]}"; do
    case "$l" in
      *SC1036*|*SC1072*|*SC1073*) parse+=("$l"); continue;;    # shellcheck cannot parse the line: nearly always a quote or bracket out of step
      *giooutput.sh:*SC2168*) continue;;                       # accepted: giooutput.sh is always sourced from inside a function
      *SC2168*) parse+=("$l"); continue;;                      # 'local' outside a function anywhere else: works only by accident of how the file is sourced
      *SC2164*) continue;;
      *SC2027*|*SC1078*|*SC1079*) continue;;                  # quote juggling inside multi-line SQL strings
    esac
    kept+=("$l")
  done
  # A line shellcheck cannot parse is a likely bug that bash -n will NOT report (bash only reads the inside of a
  # $( ... ) when it runs it), so these are failures, not warnings.
  if [[ ${#parse[@]} -gt 0 ]]; then fail "shellcheck cannot parse these lines, or found a misplaced local (look for a stray quote or bracket, or a local outside a function)" "${parse[@]:0:12}"; fi
  if [[ ${#kept[@]} -eq 0 ]]; then
    [[ ${#parse[@]} -eq 0 ]] && pass "no new shellcheck findings"
  else
    warn "${#kept[@]} shellcheck finding(s)" "${kept[@]:0:25}"
  fi
}

# ----------------------------------------------------------------------------------------------------
# 3. Every file that one script sources must exist, and every bin script must be sourced by someone
# ----------------------------------------------------------------------------------------------------
function check_sources {
  heading "3. source references"
  local missing=() refs="$TMP/refs.txt" f name
  : > "$refs"
  for f in "${ALL[@]}"; do
    $GREP -ohE '(source|^[[:space:]]*\.)[[:space:]]+"\$CONFDIR/bin/[A-Za-z0-9_.-]+' "$f" 2>/dev/null |
      sed -E 's#.*bin/##' >> "$refs"
  done
  sort -u "$refs" -o "$refs"
  while IFS= read -r name; do
    [[ -f $BIN/$name ]] || missing+=("$name is sourced but does not exist in bin")
  done < "$refs"
  if [[ ${#missing[@]} -eq 0 ]]; then pass "every sourced bin script exists"; else fail "missing sourced files" "${missing[@]}"; fi

  local orphans=()
  for f in "$BIN"/*.sh; do
    name=$(basename "$f")
    [[ $name == giocoso4.sh || $name == giocoso-installer.sh ]] && continue
    $GREP -qx "$name" "$refs" || orphans+=("$name is never sourced by any script")
  done
  if [[ ${#orphans[@]} -eq 0 ]]; then pass "every bin script is sourced somewhere"; else warn "possible orphans" "${orphans[@]}"; fi
}

# ----------------------------------------------------------------------------------------------------
# 4. The installer's download list must match the scripts actually in bin
# ----------------------------------------------------------------------------------------------------
function check_installer_list {
  heading "4. installer download list vs bin folder"
  if [[ ! -f $INSTALLER ]]; then warn "no installer found; skipping"; return; fi
  local listed="$TMP/listed.txt" actual="$TMP/actual.txt" line
  # The first components=( ... ) array is the bin list
  line=$($GREP -m1 -E '^components=\(.*\.sh' "$INSTALLER")
  if [[ -z $line ]]; then warn "could not find the bin components array in the installer"; return; fi
  echo "$line" | sed -E 's/^components=\(//; s/\)[[:space:]]*$//' | tr ' ' '\n' | $GREP -v '^$' | sort -u > "$listed"
  for f in "$BIN"/*.sh; do basename "$f"; done | $GREP -vE '^(giocoso4|giocoso-installer)\.sh$' | sort -u > "$actual"
  local notinstalled notpresent
  notinstalled=$(comm -13 "$listed" "$actual")
  notpresent=$(comm -23 "$listed" "$actual")
  if [[ -z $notinstalled && -z $notpresent ]]; then
    pass "installer lists exactly the $(wc -l < "$actual" | tr -d ' ') scripts in bin"
  else
    [[ -n $notinstalled ]] && fail "in bin but NOT in the installer's list (would never be installed)" $notinstalled
    [[ -n $notpresent ]] && fail "in the installer's list but missing from bin (download would fail)" $notpresent
  fi
}

# ----------------------------------------------------------------------------------------------------
# 5. Files under $CONFDIR/txt, tmp and art: names mentioned only once, or removed/read but never written
# ----------------------------------------------------------------------------------------------------
function check_filenames {
  heading "5. flag-file and data-file names"
  local names="$TMP/names.txt" f
  : > "$names"
  for f in "${ALL[@]}"; do
    $GAWK -v F="${f#$ROOT/}" '
      {
        line = $0
        sub(/[[:space:]]#.*$/, "", line)
        while (match(line, /\$\{?CONFDIR\}?"?\/(txt|tmp|art)\/[A-Za-z0-9_.*-]+/)) {
          item = substr(line, RSTART, RLENGTH)
          rest = substr(line, 1, RSTART - 1)
          sub(/^.*\//, "", item); kind = "ref"
          if (rest ~ /(touch|>>?|-O|tee( -a)?|cp [^ ]+|mv [^ ]+)[[:space:]]*"?$/) kind = "write"
          else if (rest ~ /[A-Za-z_][A-Za-z0-9_]*=[(]?"?$/) kind = "assign"     # VAR="$CONFDIR/tmp/x.html": the name is built here, used via VAR
          else if (rest ~ /rm( -f)?[[:space:]]*"?$/ || rest ~ /rm -f[^;|&]*$/) kind = "remove"
          print item "\t" kind "\t" F ":" NR
          line = substr(line, RSTART + RLENGTH)
        }
      }' "$f" >> "$names"
  done
  # Names the installer ships (its art, font, sound and executable lists) count as "created": a file that is
  # downloaded by the installer and used once by a script is not a typo suspect.
  if [[ -f $INSTALLER ]]; then
    $GREP -E '^[[:space:]]*components=\(' "$INSTALLER" | sed -E 's/^[[:space:]]*components=\(//; s/\)[[:space:]]*$//' | tr ' ' '\n' |
      $GREP -vE '^$|\.sh$' | awk '{print $1 "\tassign\tinstaller"}' >> "$names"
  fi
  # Names with a wildcard, the shipped assets and the directories handled elsewhere are not interesting
  local once removed_only
  # A name mentioned once, and not as the creation of a file or variable, is a typo suspect
  once=$(awk -F'\t' '$1 !~ /[*]/ && $1 !~ /-$/ {n[$1]++; k[$1]=$2} END {for (x in n) if (n[x]==1 && k[x]!="assign" && k[x]!="write") print x}' "$names" | sort)
  local lines=()
  for n in $once; do lines+=("$n  ($(awk -F'\t' -v n="$n" '$1==n {print $2 " at " $3}' "$names"))"); done
  if [[ ${#lines[@]} -eq 0 ]]; then pass "no file name appears only once"; else warn "file names mentioned exactly once (typo suspects)" "${lines[@]}"; fi

  removed_only=$(awk -F'\t' '
    $2=="remove" {r[$1]=r[$1] " " $3}
    $2=="write" || $2=="assign" {w[$1]=1}
    $2=="ref" {x[$1]=1}
    END { for (n in r) if (!(n in w) && !(n in x) && n !~ /[*]/) print n "  (" r[n] ")" }' "$names" | sort)
  if [[ -z $removed_only ]]; then pass "everything that is removed is also written or read somewhere"
  else
    mapfile -t _ro <<< "$removed_only"
    warn "removed but never created or read: a misspelt name, or a leftover from older code" "${_ro[@]}"
  fi
}

# ----------------------------------------------------------------------------------------------------
# 6. Known gotchas: patterns that have bitten before, kept here so they never come back
# ----------------------------------------------------------------------------------------------------
function gotcha {
  # $1 = FAIL or WARN, $2 = description, $3 = extended regex, $4 = optional regex of lines to ignore
  local level="$1" desc="$2" rx="$3" excl="${4:-^\$never-matches\$}" hits=() f l
  for f in "${ALL[@]}"; do
    while IFS= read -r l; do
      [[ -z $l ]] && continue
      hits+=("${f#$ROOT/}:$l")
    done < <($GREP -nE -- "$rx" "$f" 2>/dev/null | $GREP -vE -- "$excl" | $GREP -vE '^[0-9]+:[[:space:]]*#' | cut -c1-110)
  done
  local shown=("${hits[@]:0:12}")
  [[ ${#hits[@]} -gt 12 ]] && shown+=("... and $(( ${#hits[@]} - 12 )) more")
  if [[ ${#hits[@]} -eq 0 ]]; then pass "$desc"
  elif [[ $level == FAIL ]]; then fail "$desc" "${shown[@]}"
  else warn "$desc" "${shown[@]}"; fi
}

function check_gotchas {
  heading "6. known gotchas"
  gotcha FAIL "no 'unset \$VAR' (unsets the variable named by the value)"          'unset[[:space:]]+\$'
  gotcha FAIL "no '\$(<file 2>/dev/null)' (returns nothing: use cat)"              '\$\(<[^)]*2>'
  gotcha FAIL "no 'giomenuoptions' used as a command (it is a file: use gmenuoptions)" '(^|[;&|(]|then|do)[[:space:]]*giomenuoptions([[:space:]]|$)'
  gotcha FAIL "no ImageMagick call reading and writing albumart.jpg (makes -0/-1 files)" '\$MAGICK[[:space:]]+"[^"]*albumart\.jpg"[[:space:]]+-size'
  gotcha FAIL "no 'rm -f \"\$CONFDIR/xxx.txt\"' straight into the root (flag files live in txt/)" 'rm -f[[:space:]]+"?\$CONFDIR/[A-Za-z0-9_.-]+\.txt'
  gotcha FAIL "no unquoted \${PROCONN[@]}"                                          '[^"]\$\{PROCONN\[@\]\}' '"\$\{PROCONN'
  gotcha FAIL "no doubled closing quote after an expansion (\"\${X}\"\" -N ...): throws every later quote out of step" '\}""[[:space:]]'
  gotcha WARN "no single-bracket string test on an unquoted variable: '[ \$var == x ]' errors if empty" '(^|[^[])\[ \$[A-Za-z_]+ (==|=|!=) '
  gotcha WARN "no single-bracket '[ -z \$var ]' (use [[ ]], which copes with spaces and empties)" '(^|[^[])\[ -[zn] \$[A-Za-z_]+ \]'
  gotcha WARN "no plain 'sed' where \$SEDPROG should be used (BSD sed behaves differently)" '(\||\$\(|^[[:space:]]*)sed[[:space:]]' 'SEDPROG|giotput\.sh|giooscheck\.sh|applications/giocoso\.desktop|(command -v|which) sed'
}

# ----------------------------------------------------------------------------------------------------
# 7. Functions: calls to ones that do not exist, and ones that are never called
# ----------------------------------------------------------------------------------------------------
function check_functions {
  heading "7. functions"
  local defs="$TMP/defs.txt" body="$TMP/body.txt" f
  : > "$defs"; : > "$body"
  for f in "${ALL[@]}"; do
    $GREP -ohE '^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(\(\))?[[:space:]]*\{[[:space:]]*$' "$f" |
      sed -E 's/^[[:space:]]*(function[[:space:]]+)?//; s/[[:space:]]*(\(\))?[[:space:]]*\{[[:space:]]*$//' >> "$defs"
    # code with comments stripped, for call searches
    sed -E 's/^[[:space:]]*#.*$//; s/[[:space:]]+#[[:space:]].*$//' "$f" >> "$body"
  done
  sort -u "$defs" -o "$defs"
  # Words that are both case labels and function names (not real functions)
  local never=() fn n
  while IFS= read -r fn; do
    # Calls only: a definition line ("function name {") does not match this pattern, so nothing to subtract
    n=$($GAWK -v fn="$fn" '
      { if ($0 ~ ("((^|[;&|(!]|[$][(])[ \t]*|(then|do|else|if|elif|while|until)[ \t]+)" fn "([ \t;)]|$)")) c++
        else if ($0 ~ ("trap[ \t]+[\"\x27]?" fn "([ \t\"\x27]|$)")) c++ }
      END { print c + 0 }' "$body")
    [[ $n -eq 0 ]] && never+=("$fn")
  done < "$defs"
  if [[ ${#never[@]} -eq 0 ]]; then pass "every function is called somewhere"; else warn "functions that are defined but never called" "${never[@]}"; fi

  # Calls to underscore-style names (function-like) that are not defined anywhere
  local calls="$TMP/calls.txt" undefined=()
  $GREP -ohE '((^|[;&|(!]|\$\()[[:space:]]*|(then|do|else|if|elif|while|until)[[:space:]]+)[a-z][a-z0-9]*_[a-z0-9_]+([[:space:]]|;|\)|$)' "$body" |
    sed -E 's/^[;&|(!]?[[:space:]]*((then|do|else|if|elif|while|until)[[:space:]]+|\$\()?[[:space:]]*//; s/[[:space:];)]*$//' | sort -u > "$calls"
  while IFS= read -r n; do
    [[ -z $n ]] && continue
    $GREP -qx "$n" "$defs" && continue
    command -v "$n" >/dev/null 2>&1 && continue
    case "$n" in sw_vers|edit_existing|view_any|os_type|global_recordings|query_name|duration_secs|daily_seconds|x86_64) continue;; esac
    undefined+=("$n")
  done < "$calls"
  if [[ ${#undefined[@]} -eq 0 ]]; then pass "no calls to undefined functions"; else warn "function-like words that are not defined (review)" "${undefined[@]}"; fi
}

# ----------------------------------------------------------------------------------------------------
# 8. Variables: used but never assigned anywhere in the tree (catches typos such as DISPLAYTEXT/DISPLAYTXT)
# ----------------------------------------------------------------------------------------------------
function check_variables {
  heading "8. variables used but never assigned"
  local used="$TMP/used.txt" assigned="$TMP/assigned.txt" body="$TMP/vbody.txt" f
  : > "$body"
  for f in "${ALL[@]}"; do sed -E 's/^[[:space:]]*#.*$//' "$f" >> "$body"; done
  # Variables read: $NAME or ${NAME...} with at least 4 characters, upper-case style
  $GREP -ohE '\$\{?[A-Z][A-Za-z0-9_]{3,}' "$body" | sed -E 's/^\$\{?//' | sort -u > "$used"
  # Variables assigned: NAME= / NAME+= / for NAME in / read NAME / local NAME / printf -v NAME / declare NAME
  {
    $GREP -ohE '(^|[^A-Za-z0-9_$])[A-Z][A-Za-z0-9_]{3,}\+?=' "$body" | sed -E 's/^[^A-Z]*//; s/\+?=$//'
    $GREP -ohE 'for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in' "$body" | awk '{print $2}'
    $GREP -ohE '(read|local|declare|typeset|printf -v|mapfile|readarray)[^;|&]*' "$body" | tr ' ' '\n' | $GREP -E '^[A-Z][A-Za-z0-9_]{3,}$'
    $GREP -ohE '\(\([[:space:]]*[A-Z][A-Za-z0-9_]{3,}[[:space:]]*(\+\+|--|[-+*/]?=)' "$body" | $GREP -oE '[A-Z][A-Za-z0-9_]{3,}'
    $GREP -ohE '\(\(\(?[[:space:]]*(\+\+|--)[A-Z][A-Za-z0-9_]{3,}' "$body" | $GREP -oE '[A-Z][A-Za-z0-9_]{3,}'
  } | sort -u > "$assigned"
  # Supplied from outside the scripts: the shell, the environment, the configuration file and programvariables.txt
  local ext="HOME PATH PWD OLDPWD USER LOGNAME SHELL TERM LANG DISPLAY TMPDIR HOSTNAME IFS OSTYPE MACHTYPE HOSTTYPE
    BASH BASHPID BASH_VERSION BASH_SOURCE BASH_REMATCH PIPESTATUS FUNCNAME RANDOM SECONDS LINENO OPTARG OPTIND REPLY UID EUID
    LC_ALL LC_CTYPE LC_NUMERIC BROWSER PULSE_SERVER DIALOGRC DIALOGOPTS XDG_RUNTIME_DIR COLUMNS LINES"
  local cfg="$TMP/cfg.txt"
  # Configuration keys are read with grep KEY= (not assigned as KEY= in code) so allow what gioparse.sh reads
  $GREP -ohE '[A-Z][A-Z0-9_]{3,}=' "$BIN"/gioparse.sh "$BIN"/gioconfconstruct.sh "$BIN"/giooscheck.sh 2>/dev/null | tr -d '=' | sort -u > "$cfg"
  printf '%s\n' $ext | sort -u > "$TMP/ext.txt"
  local unknown
  unknown=$(comm -23 "$used" "$assigned" | comm -23 - "$TMP/ext.txt" | comm -23 - "$cfg")
  if [[ -z $unknown ]]; then pass "every upper-case variable that is read is assigned somewhere"
  else
    mapfile -t _u <<< "$unknown"
    warn "read but never assigned in any script (typo, or set by the config file / programvariables.txt?)" "${_u[@]:0:40}"
  fi
}

# ----------------------------------------------------------------------------------------------------
# 9. Release hygiene
# ----------------------------------------------------------------------------------------------------
function check_hygiene {
  heading "9. release hygiene"
  local bad=() f
  for f in "${ALL[@]}"; do
    [[ $(head -c2 "$f") == '#!' ]] || bad+=("${f#$ROOT/}: does not start with #! (the installer's download check would reject it)")
  done
  if [[ ${#bad[@]} -eq 0 ]]; then pass "every script starts with #!"; else fail "missing shebang" "${bad[@]}"; fi

  bad=()
  for f in "${ALL[@]}"; do
    $GREP -q $'\r' "$f" && bad+=("${f#$ROOT/}")
  done
  if [[ ${#bad[@]} -eq 0 ]]; then pass "no Windows (CRLF) line endings"; else fail "CRLF line endings" "${bad[@]}"; fi

  bad=$(find "$ROOT" \( -name '.DS_Store' -o -name '__MACOSX' -o -name '._*' -o -name '*.bak' -o -name '*~' -o -name '*.orig' \) 2>/dev/null | short)
  if [[ -z $bad ]]; then pass "no .DS_Store / __MACOSX / backup files"; else mapfile -t _h <<< "$bad"; warn "stray files that should not be published (harmless in a live install: leave them out of the release zip)" "${_h[@]}"; fi

  bad=()
  for f in "${ALL[@]}"; do
    $GREP -nE 'whichdir\.txt|pause-debug|/tmp/debug|DEBUG=|debug\.txt' "$f" 2>/dev/null | $GREP -v '^[0-9]*:[[:space:]]*#' | head -2 | sed "s#^#${f#$ROOT/}:#" | while IFS= read -r l; do echo "$l"; done
  done > "$TMP/debug.txt"
  if [[ ! -s $TMP/debug.txt ]]; then pass "no leftover debug writes"; else mapfile -t _d < "$TMP/debug.txt"; warn "possible leftover debug lines" "${_d[@]}"; fi
}

# ----------------------------------------------------------------------------------------------------
echo "Giocoso static checks"
echo "Root: $ROOT   (scripts in: ${BIN#$ROOT/}${BIN:+ })   Scripts examined: ${#ALL[@]}"
check_syntax
check_shellcheck
check_sources
check_installer_list
check_filenames
check_gotchas
check_functions
check_variables
check_hygiene
echo
echo "Result: $PASSES passed, $WARNS warning(s), $FAILS failure(s)"
[[ $FAILS -eq 0 ]]