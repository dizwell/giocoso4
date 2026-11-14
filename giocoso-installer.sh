#!/usr/bin/env bash
####################################################################
#
# Installation Program for Giocoso Version 4. In broad terms:
#
#  1. Get user consent to adjust system
#  2. Install software dependencies
#  3. Install new Giocoso 4
#  4. Re-point giocoso softlink to giocoso4.sh
#  5. Configure default dialog colour scheme
#  6. Install new fonts
#
####################################################################
# Preliminary variables settings
PROGVERSION=4.00 COPYRIGHT="2019-2026"
clear; USERNAME=$(whoami); ERRORCOUNT=0  YPOS=6
GIORELEASE=""    GIODISTRO=""
NEWCONF="$HOME/.local/share/giocoso4"
CONFDIR="$NEWCONF"
# The installer deletes itself when it finishes or is cancelled, whatever it was saved as (sem4inst, gio4inst...),
# unless it's the copy inside a program's own repository folder
INSTALLERFILE="$0"
if git -C "$(dirname "$INSTALLERFILE")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then INSTALLERFILE=""; fi

HOTKEY=11 DRAWLINES=2 MAINTEXT=11 LOGO=6 INFOTEXT=11 SPINNER=12 ALERT=1

# Determine if the user has invoked the installer with a specific distro
# or release flavour in mind
while getopts "v:d:" opt; do
	case "$opt" in
	  v)  GIORELEASE="$OPTARG";;
	  d)  GIODISTRO="$OPTARG";;
	esac
done

# -v must be beta or stable; if it's left out, choose_release asks which (after "Do you wish to proceed?")
case "$GIORELEASE" in
  beta|stable|"") ;;
  *) echo "Unknown release '$GIORELEASE': use -v beta or -v stable."; exit 1 ;;
esac

function choose_release {
if [[ -z $GIORELEASE ]]; then
  clear; print_header
  tput cup 6 4; tput setaf $INFOTEXT; echo "You have a choice of whether to install the stable or beta release of Giocoso. Beta releases contain all the latest fixes and new features but have not been thoroughly tested on every supported platform and might break, badly. Stable releases have been tested to work correctly on all supported platforms." | fold -s -w 76 | sed '2,$s/^/    /'
  echo ""
  while true; do
    tput setaf $ALERT; read -s -n 1 -p "    Choose now whether to install the stable or beta release (s/b): " input
    case "$input" in
      [sS]) GIORELEASE="stable"; break ;;
      [bB]) GIORELEASE="beta"; break ;;
      *) echo ""; echo ""; tput setaf $MAINTEXT; echo "    Invalid input: only s or b are allowed. Please try again."; echo "" ;;
    esac
  done
fi

# Everything is fetched from GitHub: the beta branch (work in progress) or main (releases)
if [[ $GIORELEASE == "beta" ]]; then
  REMOTESOURCE="https://raw.githubusercontent.com/dizwell/giocoso4/beta"
else
  REMOTESOURCE="https://raw.githubusercontent.com/dizwell/giocoso4/main"
fi
}

function exit_program {
rm -f "$INSTALLERFILE" >/dev/null 2>&1
reset
exit 1
}

# Download one file, trying up to five times; it only counts if it arrives and isn't empty
function fetch_file {
  for attempt in {1..5}; do
    if wget -q --tries=1 "$1" -O "$2" && [[ -s "$2" ]]; then return 0; fi
    rm -f "$2"
    sleep 1
  done
  return 1
}

trap exit_program TERM      # Trap to quit nicely if the terminal is closed by clicking 'X' icon in window titlebar
trap exit_program SIGHUP    # Same thing, different signal
trap exit_program INT       # Trap to prevent Ctrl+C from working

tput() {
	local VERSION='bash tput (1.0.0)'

	local opt OPTIND OPTARG
	while getopts 'ST:V' opt; do
		case "$opt" in
			S) command tput "$@"; return $?;;
			T) true;;
			V) echo "$VERSION"; return 0;;
		esac
	done
	shift "$((OPTIND - 1))"

	local ESC=$'\x1b'
	case "$1" in
		bel) echo -n $'\x7';;
		sgr0 | me) echo -n "$ESC[0m";;
		bold) echo -n "$ESC[1m";;
		dim) echo -n "$ESC[2m";;
		rev) echo -n "$ESC[7m";;
		blink) echo -n "$ESC[5m";;
		setaf | AF) echo -n "$ESC[38;5;$2m";;
		setab | AB) echo -n "$ESC[48;5;$2m";;
		sc) echo -n "${ESC}7";;
		rc) echo -n "${ESC}8";;
		cnorm) echo -n "$ESC[?25h";;
		civis) echo -n "$ESC[?25l";;
		smcup) echo -n "$ESC[?1049h";;
		rmcup) echo -n "$ESC[?1049l";;
		clear) echo -n "$ESC[H$ESC[2J";;
		home) echo -n "$ESC[H";;
		cuu) echo -n "$ESC[$2A";;
		cud) echo -n "$ESC[$2B";;
		cuf) echo -n "$ESC[$2C";;
		cub) echo -n "$ESC[$2D";;
		cup)
			local row=$(($2 + 1))
			local col=$(($3 + 1))
			echo -n "$ESC[$row;${col}H";;
		*) command tput "$@"; return $?;;
	esac
}

# Attempt to resize the terminal to 29 rows and 105 columns.
tput civis; printf '\e[8;29;105t'

function print_header {
tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
tput cup  1 4; tput setaf $LOGO; echo "♬♪ Giocoso Music Player Installer ♬♪"
tput cup  2 4; tput setaf $LOGO; echo "Copyright © H. Rogers $COPYRIGHT"
tput cup  3 4; tput setaf $LOGO; echo "Version $PROGVERSION"
# Once known (from -v, or from the stable/beta prompt), the release being installed shows flush right
if [[ -n $GIORELEASE ]]; then
  RELTEXT="INSTALLING $(tr "[:lower:]" "[:upper:]" <<< "$GIORELEASE") RELEASE"
  tput cup  3 $(( 97 - ${#RELTEXT} )); tput setaf $LOGO; echo "$RELTEXT"
fi
}

function downloads {
# 4. Fetch Giocoso components: BIN files first
components=(gioadvsql.sh gioart.sh gioaudtst.sh giobkpdb.sh giocolour.sh gioconfconstruct.sh giocontrol.sh giocount.sh giodefsrch.sh giodirselect.sh gioexcludes.sh gioexempts.sh giofilter.sh giofunctions.sh gioglobresume.sh giomenudraw.sh giomenuoptions.sh giominifilter.sh giominip.sh giomplay.sh giooscheck.sh giooutput.sh gioparse.sh giophoneme.sh gioplay.sh gioplaylist.sh giopsink.sh gioqrydel.sh giorefreshdb.sh gioretnote.sh giorptadvsql.sh giorptaggstats.sh giorptallrecs.sh giorptdevos.sh giorptexcludes.sh giorptlastplayed.sh giorptplayhist.sh giorpttopcomp.sh giospin.sh giosql.sh giotput.sh)
BINCOMPONENTS=("${components[@]}")                                  # Remembered for the final installation check
total=${#components[@]}
count=0
(
for f in "${components[@]}"; do
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/bin/$f" -O "$NEWCONF/bin/$f" && [[ $(head -c2 "$NEWCONF/bin/$f") == '#!' ]]; then
      downloaded=1
      break
    fi
    rm -f "$NEWCONF/bin/$f"
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then exit 1; fi	
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  sleep 0.1
done
) | dialog --title " Installing Giocoso Binary Components " --gauge "\\n\\nDownloading Giocoso's own software components: this might take some time..." 12 70

download_status=${PIPESTATUS[0]}
if [[ $download_status -ne 0 ]]; then
  dialog --title " Download Failed " --msgbox "A Giocoso component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
  exit 1
fi

# Art files next
components=(giocosoicobeta.png genericalbumart.jpg giocosoico.png testaudio.flac LibreBaskerville-Regular.ttf LinLibertine_M.otf silence.flac)
total=${#components[@]}
count=0
(
  for f in "${components[@]}"; do
    downloaded=0
    for attempt in {1..5}; do
	  if wget -q --tries=1 "$REMOTESOURCE/art/$f" -O "$NEWCONF/art/$f"; then
	    downloaded=1
	    break
	  fi
	  rm -f "$NEWCONF/art/$f"
	  sleep 1
	done
	if [[ $downloaded -eq 0 ]]; then exit 1; fi	  
    count=$((count + 1 ))
    percent=$((count * 100 / total))
    echo $percent
    sleep 0.1
  done
) | dialog --title " Installing Giocoso Art Components " --gauge "\\n\\nNow downloading some other Giocoso bits and pieces..." 12 70

download_status=${PIPESTATUS[0]}
if [[ $download_status -ne 0 ]]; then
  dialog --title " Download Failed " --msgbox "A Giocoso component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
  exit 1
fi

# Now the executables. 
components=(ffmpeg-linux-arm64 ffmpeg-linux-x86_64 ffmpeg-macos-arm64 ffmpeg-macos-x86_64 ffprobe-linux-arm64 ffprobe-linux-x86_64 ffprobe-macos-arm64 ffprobe-macos-x86_64 flac-linux-arm64 flac-linux-x86_64 flac-macos-arm64 flac-macos-x86_64 img2sixel-linux-arm64 img2sixel-linux-x86_64 img2sixel-macos-arm64 img2sixel-macos-x86_64 magick-linux-arm64 magick-linux-x86_64 magick-macos-arm64 magick-macos-x86_64 metaflac-linux-arm64 metaflac-linux-x86_64 metaflac-macos-arm64 metaflac-macos-x86_64)
total=${#components[@]}
count=0
(
  for f in "${components[@]}"; do
    downloaded=0
    for attempt in {1..5}; do
      if wget -q --tries=1 "$REMOTESOURCE/exec/$f" -O "$NEWCONF/exec/$f"; then
  	    downloaded=1
  	    break
  	  fi
  	  rm -f "$NEWCONF/exec/$f"
  	  sleep 1
  	done
  	if [[ $downloaded -eq 0 ]]; then exit 1; fi	 	  
	count=$((count + 1 ))
    percent=$((count * 100 / total))
    echo $percent
    sleep 0.1
  done
) | dialog --title " Installing Giocoso Binary Components " --gauge "\\n\\nNow downloading some external binaries Giocoso depends on: not long to wait now..." 12 70

download_status=${PIPESTATUS[0]}
if [[ $download_status -ne 0 ]]; then
  dialog --title " Download Failed " --msgbox "A Giocoso component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
  exit 1
fi

chmod +x "$NEWCONF/exec/"*


# Get the XML files into ../txt for ImageMagick
components=(colors.xml configure.xml delegates.xml type.xml)
total=${#components[@]}
count=0
(
  for f in "${components[@]}"; do
	downloaded=0
    for attempt in {1..5}; do
  	  if wget -q --tries=1 "$REMOTESOURCE/txt/$f" -O "$NEWCONF/txt/$f"; then
  	    downloaded=1
  	    break
  	  fi
  	  rm -f "$NEWCONF/txt/$f"
  	  sleep 1
  	done
  	if [[ $downloaded -eq 0 ]]; then exit 1; fi	 
    count=$((count + 1 ))
    percent=$((count * 100 / total))
    echo $percent
    sleep 0.1
  done
) | dialog --title " Installing Giocoso Binary Components " --gauge "\\n\\nLast lot of files to download..." 12 70

download_status=${PIPESTATUS[0]}
if [[ $download_status -ne 0 ]]; then
  dialog --title " Download Failed " --msgbox "A Giocoso component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
  exit 1
fi

# Finally, /usr/bin and miscellaneous stuff
if [[ $OS == "DARWIN" ]]; then
  rm -f "$NEWCONF/giocoso4.sh"
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/giocoso4.sh" -O "$NEWCONF/giocoso4.sh" && [[ $(head -c2 "$NEWCONF/giocoso4.sh") == '#!' ]]; then
      downloaded=1
      break
    fi
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then
    dialog --title " Download Failed " --msgbox "A Giocoso component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    rm -f "$NEWCONF/giocoso4.sh"
    exit 1
  fi
  chmod +x "$NEWCONF/giocoso4.sh"
  
  rm -f "$NEWCONF/db/global_phonemes.sql"
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/db/global_phonemes.sql" -O "$NEWCONF/db/global_phonemes.sql"; then
      downloaded=1
      break
    fi
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then
    dialog --title " Download Failed " --msgbox "A Giocoso component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    exit 1
  fi  
  
else
  rm -f "$NEWCONF/giocoso4.sh"
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/giocoso4.sh" -O "$NEWCONF/giocoso4.sh" && [[ $(head -c2 "$NEWCONF/giocoso4.sh") == '#!' ]]; then
      downloaded=1
      break
    fi
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then
    dialog --title " Download Failed " --msgbox "A Giocoso component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    rm -f "$NEWCONF/giocoso4.sh"
    exit 1
  fi
  chmod +x "$NEWCONF/giocoso4.sh"

  rm -f "$NEWCONF/db/global_phonemes.sql"
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/db/global_phonemes.sql" -O "$NEWCONF/db/global_phonemes.sql"; then
      downloaded=1
      break
    fi
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then
    dialog --title " Download Failed " --msgbox "A Giocoso component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    exit 1
  fi
fi

# Run the import to populate global_phonemes
"${PROCONN[@]}" < "$CONFDIR/db/global_phonemes.sql" 1>&2 2>/dev/null

# Create a desktop launcher for Linux
if ! [[ $OS == "DARWIN" ]]; then
  if [[ ! -d "$HOME/.local/share/applications" ]]; then mkdir -p "$HOME/.local/share/applications/"; fi
  if [[ ! -f "$HOME/.local/share/applications/giocoso.desktop" ]]; then
    downloaded=0
    for attempt in {1..5}; do
      if wget -q --tries=1 "$REMOTESOURCE/giocoso.desktop" -O "$HOME/.local/share/applications/giocoso.desktop"; then
        downloaded=1
        break
      fi
      rm -f "$HOME/.local/share/applications/giocoso.desktop"
      sleep 1
    done
    if [[ $downloaded -eq 0 ]]; then
      dialog --title " Download Failed " --msgbox "A Giocoso component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
      exit 1
    fi
    sed -i "s|xxxxxxxx|$USERNAME|" "$HOME/.local/share/applications/giocoso.desktop"
    chmod +x "$HOME/.local/share/applications/giocoso.desktop"
    ln -s "$HOME/.local/share/applications/giocoso.desktop" "$HOME/Desktop" 2>/dev/null
  fi
  
# And now do one for macOS
else
  APPNAME="Giocoso"
  APPPATH="/Applications/$APPNAME.app"
  ICONPNG="$HOME/.local/share/giocoso4/art/giocosoico.png"
  ICONSET="/tmp/giocoso.iconset"
  ICONFILE="/tmp/giocoso.icns"

  rm -rf "$APPPATH" >/dev/null 2>&1
  mkdir -p "$APPPATH/Contents/MacOS" "$APPPATH/Contents/Resources" >/dev/null 2>&1

  cat > "$APPPATH/Contents/MacOS/$APPNAME" <<EOF
#!/bin/bash
# Use the first bash and WezTerm found: Homebrew (Apple Silicon or Intel), MacPorts, then WezTerm's own app
for bashPath in /opt/homebrew/bin/bash /usr/local/bin/bash /opt/local/bin/bash; do
  [[ -x "\$bashPath" ]] && break
done
for weztermPath in /opt/homebrew/bin/wezterm /usr/local/bin/wezterm /opt/local/bin/wezterm /Applications/WezTerm.app/Contents/MacOS/wezterm; do
  [[ -x "\$weztermPath" ]] && break
done

exec "\$weztermPath" --config-file "\$HOME/.giocoso.lua" start -- "\$bashPath" -l -c 'ulimit -u 4000; exec "\$BASH" /usr/local/bin/giocoso4.sh'
EOF

  chmod +x "$APPPATH/Contents/MacOS/$APPNAME"
  
  cat > "$APPPATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleExecutable</key>
<string>$APPNAME</string>
<key>CFBundleIdentifier</key>
<string>com.bbritten.giocoso4</string>
<key>CFBundleName</key>
<string>$APPNAME</string>
<key>CFBundleDisplayName</key>
<string>$APPNAME</string>
<key>CFBundlePackageType</key>
<string>APPL</string>
<key>CFBundleIconFile</key>
<string>giocoso.icns</string>
<key>LSArchitecturePriority</key>
<array>
  <string>arm64</string>
  <string>x86_64</string>
</array>
</dict>
</plist>
EOF

  rm -rf "$ICONSET" >/dev/null 2>&1
  mkdir -p "$ICONSET" >/dev/null 2>&1
  sips -z 16 16     "$ICONPNG" --out "$ICONSET/icon_16x16.png" >/dev/null 2>&1
  sips -z 32 32     "$ICONPNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null 2>&1
  sips -z 32 32     "$ICONPNG" --out "$ICONSET/icon_32x32.png" >/dev/null 2>&1
  sips -z 64 64     "$ICONPNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null 2>&1
  sips -z 128 128   "$ICONPNG" --out "$ICONSET/icon_128x128.png" >/dev/null 2>&1
  sips -z 256 256   "$ICONPNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null 2>&1
  sips -z 256 256   "$ICONPNG" --out "$ICONSET/icon_256x256.png" >/dev/null 2>&1
  sips -z 512 512   "$ICONPNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null 2>&1
  sips -z 512 512   "$ICONPNG" --out "$ICONSET/icon_512x512.png" >/dev/null 2>&1
  sips -z 1024 1024 "$ICONPNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null 2>&1

  iconutil -c icns "$ICONSET" -o "$ICONFILE" >/dev/null 2>&1
  cp "$ICONFILE" "$APPPATH/Contents/Resources/giocoso.icns" >/dev/null 2>&1

  rm -rf "$ICONSET" >/dev/null 2>&1
  rm -f "$ICONFILE" >/dev/null 2>&1
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APPPATH" >/dev/null 2>&1
fi
    
# Confirmation when concluded
dialog --title " Software Components Completed " --msgbox "\\n\\nAll Giocoso's components have now been installed successfully.\\n\\nPress OK to see an installation summary report." 12 70
}

function verify_install {
# A quick, silent check of Giocoso's key abilities, reported as a checklist (as Semplice's installer does)
local P A T="$NEWCONF/art/testaudio.flac" TMPIMG="/tmp/giocheck-$$.jpg" DBCLIENT DIALOGTEXT ALLOK=1 c
case "$(uname -s)" in Darwin) P="macos" ;; *) P="linux" ;; esac
case "$(uname -m)" in arm64|aarch64) A="arm64" ;; *) A="x86_64" ;; esac
local X="$NEWCONF/exec"

local BASICOK=1                                             # Every bin script present, plus the main script and its command link
for c in "${BINCOMPONENTS[@]}"; do [[ -f $NEWCONF/bin/$c ]] || BASICOK=0; done
[[ -f $NEWCONF/giocoso4.sh ]] || BASICOK=0
[[ -e /usr/local/bin/giocoso || -e /usr/bin/giocoso ]] || BASICOK=0

local PLAYOK=0                                              # ffmpeg can decode Giocoso's own test file (silently)
"$X/ffmpeg-$P-$A" -v error -nostdin -i "$T" -f null - >/dev/null 2>&1 && PLAYOK=1

local ARTOK=0                                               # magick can make a picture, and img2sixel can convert it for display
"$X/magick-$P-$A" -size 64x64 xc:steelblue "$TMPIMG" >/dev/null 2>&1 && "$X/img2sixel-$P-$A" "$TMPIMG" >/dev/null 2>&1 && ARTOK=1
rm -f "$TMPIMG"

local TAGOK=0                                               # metaflac can read the test file's tags
"$X/metaflac-$P-$A" --list "$T" >/dev/null 2>&1 && TAGOK=1

local SPEAKOK=0                                             # The announcements' speech program
if [[ $P == "macos" ]]; then command -v say >/dev/null 2>&1 && SPEAKOK=1; else command -v espeak-ng >/dev/null 2>&1 && SPEAKOK=1; fi

local DBOK=0                                                # A Server should accept Giocoso's own login; a Client is pointed at its server later
DBCLIENT=$(command -v mariadb || command -v mysql)
if [[ $GIOSERVER == "yes" ]]; then
  [[ -n $DBCLIENT ]] && "$DBCLIENT" --connect-timeout=3 -u giocoso4 -pgiocoso4 -h 127.0.0.1 -P 3306 -D giocoso4 $SSL_OPTS -e "select 1" >/dev/null 2>&1 && DBOK=1
else
  [[ -n $DBCLIENT ]] && DBOK=2
fi

DIALOGTEXT="\nThe Giocoso installation has now completed. Its current status is as follows:\n"
if [[ $BASICOK -eq 1 ]]; then DIALOGTEXT+="\n  ✓ Your basic Giocoso installation is fine"; else DIALOGTEXT+="\n  ✘ Some of Giocoso's own files are missing"; ALLOK=0; fi
if [[ $PLAYOK -eq 1 ]]; then DIALOGTEXT+="\n  ✓ Giocoso can play music"; else DIALOGTEXT+="\n  ✘ Giocoso cannot play music (ffmpeg failed its test)"; ALLOK=0; fi
if [[ $ARTOK -eq 1 ]]; then DIALOGTEXT+="\n  ✓ Giocoso can display album art"; else DIALOGTEXT+="\n  ✘ Giocoso cannot display album art"; ALLOK=0; fi
if [[ $TAGOK -eq 1 ]]; then DIALOGTEXT+="\n  ✓ Giocoso can read FLAC tags"; else DIALOGTEXT+="\n  ✘ Giocoso cannot read FLAC tags"; ALLOK=0; fi
case $DBOK in
  1) DIALOGTEXT+="\n  ✓ Giocoso's database is up and accepting connections" ;;
  2) DIALOGTEXT+="\n  ✓ The database client is installed: set your server's address in Giocoso's configuration" ;;
  *) DIALOGTEXT+="\n  ✘ Giocoso cannot connect to its database"; ALLOK=0 ;;
esac
if [[ $SPEAKOK -eq 1 ]]; then DIALOGTEXT+="\n  ✓ Giocoso can announce what it plays"; else DIALOGTEXT+="\n  ✘ Giocoso cannot announce what it plays (no speech program)"; ALLOK=0; fi
if [[ $ALLOK -eq 1 ]]; then
  DIALOGTEXT+="\n\nGiocoso has full functionality: click OK to return to the command line."
else
  DIALOGTEXT+="\n\nSee the Giocoso documentation for how to resolve these issues. Details of any software installation problems are in Giocoso's txt/install-log.txt."
fi
dialog --stdout --backtitle "Giocoso Software Install" --title " Software installation status " --msgbox "$DIALOGTEXT" 18 80
}

function backup_database {
# Nothing to back up on a first-ever install, so skip creating an empty backup folder
if [[ ! -d "$NEWCONF" ]] && ! compgen -G "/usr/bin/giocoso*.sh" >/dev/null && ! compgen -G "/usr/local/bin/giocoso*.sh" >/dev/null; then return; fi
tput clear; print_header
tput cup 6 4; tput setaf $MAINTEXT; echo -n "Backing up prior version's program & database."
BACKUPDIR="$HOME/.local/share/giocoso-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUPDIR"
cp -r "$NEWCONF" "$BACKUPDIR" 2>/dev/null; BACKUPSUCCESS=$?
cp /usr/bin/giocoso*.sh "$BACKUPDIR" 2>/dev/null
cp /usr/local/bin/giocoso*.sh "$BACKUPDIR" 2>/dev/null

# Now prune old backups
if [[ $BACKUPSUCCESS -eq 0 ]]; then
    local count=0
    for dir in "$HOME"/.local/share/giocoso-backup-*; do
        [[ -d "$dir" ]] && echo "$dir"
    done | sort -r | while IFS= read -r dir; do
        ((count+=1))
        ((count > 5)) && rm -rf "$dir"
    done
fi
}

# ====================================================================================
# Installation Code Starts Here
# ====================================================================================

# 1. Warning
# -----------------------------------------------------
tput clear; print_header
tput cup 6 4; tput setaf $INFOTEXT; echo -e "Welcome to the Giocoso Installer."
tput cup 8 4; tput setaf $INFOTEXT; echo -e "• It will install numerous new software packages necessary for Giocoso to function correctly. It will also create a bunch of new folders within your \$HOME folder.\n\n• Any existing Giocoso installation will be backed up, just in case it's needed.\n\n• Any existing Giocoso database will NOT be backed up: you may wish to perform a manual backup before proceeding, if you wish to be cautious.\n\n• If you are happy to proceed, tap 'y' when prompted; tapping anything else will cancel the installation without it having touched your system at all." | fold -s -w 76 | sed '2,$s/^/    /'
echo ""; tput setaf $ALERT; read -s -n 1 -p "    Do you wish to proceed? (y/n): " response   # One line below the text, however long it is

if [[ "$response" == [Yy]* ]]; then
  choose_release
  clear; print_header; tput setaf $MAINTEXT; tput cup 6 0
  tput cup 6 4; echo -e "Checking your network connection is working..."
  if ! ping -c1 -W1 "1.1.1.1" >/dev/null 2>&1; then
    tput clear; print_header
    tput cup 6 4; tput setaf $ALERT; echo -e "Sadly, you do not appear to be able to reach the Internet.\n\nThis is a requirement for the Giocoso installation." | fold -s -w 76 | sed '2,$s/^/    /'
    tput cup 10 4; tput setaf $ALERT; read -n 1 -p "Quitting in the meantime. Press a key to exit."
    tput reset; tput sgr0
    exit_program
  fi

  # 2. Backup if appropriate
  # -----------------------------------------------------
  backup_database

  # 3. Make new version directory structure if needed
  # -----------------------------------------------------
  if [[ ! -d "$NEWCONF" ]]; then mkdir -p "$NEWCONF"; fi
  if [[ ! -d "$NEWCONF/art" ]]; then mkdir -p "$NEWCONF/art"; fi
  if [[ ! -d "$NEWCONF/bin" ]]; then mkdir -p "$NEWCONF/bin"; fi
  if [[ ! -d "$NEWCONF/db" ]]; then mkdir -p "$NEWCONF/db"; fi
  if [[ ! -d "$NEWCONF/play" ]]; then mkdir -p "$NEWCONF/play"; fi
  if [[ ! -d "$NEWCONF/txt" ]]; then mkdir -p "$NEWCONF/txt"; fi
  if [[ ! -d "$NEWCONF/tmp" ]]; then mkdir -p "$NEWCONF/tmp"; fi
  if [[ ! -d "$NEWCONF/exec" ]]; then mkdir -p "$NEWCONF/exec"; fi

  # 3a. Ask for the sudo password once, now, and make the command links straight away. They point at the
  # main script in the program folder, which arrives later; nothing after this needs the password again.
  # -----------------------------------------------------
  echo ""
  tput setaf $ALERT
  sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; exit_program; }
  tput setaf $MAINTEXT
  if [[ $(uname -s) == "Darwin" ]]; then BINDIR="/usr/local/bin"; else BINDIR="/usr/bin"; fi
  sudo mkdir -p "$BINDIR"
  sudo rm -f "$BINDIR/giocoso4.sh" "$BINDIR/giocoso" 2>/dev/null
  sudo ln -s "$NEWCONF/giocoso4.sh" "$BINDIR/giocoso4.sh"
  sudo ln -s "$NEWCONF/giocoso4.sh" "$BINDIR/giocoso"
  sudo sh -c 'printf "#!/usr/bin/env bash\ngiocoso --play\n" >'"$BINDIR/minig"; sudo chmod +x "$BINDIR/minig"
  
  # 4. Call giooscheck.sh and get packages installed
  # -----------------------------------------------------
  if mariadb --help 2>/dev/null | grep -q -- '--ssl-mode'; then
    SSL_OPTS="--ssl-mode=DISABLED"
  elif mariadb --help 2>/dev/null | grep -q -- '--skip-ssl'; then
    SSL_OPTS="--skip-ssl"
  else
    SSL_OPTS=""
  fi
    
  PROCONN=()
  if [[ $(uname -a) == *"Darwin"* ]]; then 
    PROCONN+=(mariadb --connect-timeout=1 -u giocoso4 -h "$MYSQLIP" -pgiocoso4 -P "$MYSQLPRT" -D giocoso4)
  else
    PROCONN+=(/usr/bin/mariadb --connect-timeout=1 -u giocoso4 -h "$MYSQLIP" -pgiocoso4 -P "$MYSQLPRT" -D giocoso4)
  fi
  if [[ -n $SSL_OPTS ]]; then
    PROCONN+=($SSL_OPTS)
  fi    
  
  YPOS=$((YPOS+1)); tput cup $YPOS 1;
  if ! fetch_file "$REMOTESOURCE/bin/giooscheck.sh" "$NEWCONF/bin/giooscheck.sh" || [[ $(head -c2 "$NEWCONF/bin/giooscheck.sh") != '#!' ]]; then
    dialog --title " Download Failed " --msgbox "A Giocoso component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    exit 1
  fi
  source "$NEWCONF/bin/giooscheck.sh" install $GIODISTRO       # Triggers a check of software dependencies and *fixes* them
  downloads
  if [[ $OS == "DARWIN" ]]; then
    chown -R $USERNAME:staff "$NEWCONF" 2>/dev/null
  else
    chown -R $USERNAME:$USERNAME "$NEWCONF" 2>/dev/null
  fi
  
  # 5. Download the various Dialog configuration files
  # -----------------------------------------------------
  fetch_file "$REMOTESOURCE/txt/standard.conf" "$NEWCONF/txt/standard.conf"
  fetch_file "$REMOTESOURCE/txt/red.conf" "$NEWCONF/txt/red.conf"
  fetch_file "$REMOTESOURCE/txt/green.conf" "$NEWCONF/txt/green.conf"
  fetch_file "$REMOTESOURCE/txt/yellow.conf" "$NEWCONF/txt/yellow.conf"
  fetch_file "$REMOTESOURCE/txt/magenta.conf" "$NEWCONF/txt/magenta.conf"

  # 6. Try to install the program fonts (but it may not work on all distros, and ultimately it's up to them)
  # -----------------------------------------------------
  if ! [[ $(uname -a) == *"Darwin"* ]]; then
    if [[ ! -d "$HOME/.local/share/fonts" ]]; then 
      mkdir -p "$HOME/.local/share/fonts" 2>/dev/null
    fi
    cp "$HOME/.local/share/giocoso4/art/"*.ttf "$HOME/.local/share/fonts/"
    cp "$HOME/.local/share/giocoso4/art/"*.otf "$HOME/.local/share/fonts/"
    fc-cache -f >/dev/null 2>&1
    clear
  fi

  if [[ $(uname -a) == *"Darwin"* ]]; then
    cp "$HOME/.local/share/giocoso4/art/LibreBaskerville-Regular.ttf" "$HOME/Library/Fonts/"
    cp "$HOME/.local/share/giocoso4/art/LinLibertine_M.otf" "$HOME/Library/Fonts/"	
  fi

  # 7. If possible, configure WezTerm terminals to display appropriately
  # -----------------------------------------------------
  if ! [[ -f "$HOME/.giocoso.lua" ]]; then
cat << 'EOF' > "$HOME/.giocoso.lua"
local wezterm = require 'wezterm'
local config = wezterm.config_builder()
config.initial_cols = 103
config.initial_rows = 28
config.color_scheme = 'Banana Blueberry'
config.font = wezterm.font("Linux Libertine Mono O", {weight="Regular", stretch="Normal", style="Normal"})
config.font_size = 12
config.audible_bell = "Disabled"
config.window_close_confirmation = "NeverPrompt"
config.mouse_bindings = {
  -- Right-click over highlighted text: Copies and instantly clears the highlight
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = wezterm.action.Multiple {
      wezterm.action.CopyTo("ClipboardAndPrimarySelection"),
      wezterm.action.ClearSelection,
	},
  },

-- Shift + Right-click: Triggers paste action
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "SHIFT",
    action = wezterm.action.PasteFrom("Clipboard"),
  },
}
config.window_decorations = "TITLE | RESIZE"
config.freetype_load_target = "Light"
config.enable_wayland = false
config.enable_tab_bar = false
config.line_height = 1.1
--config.front_end = "WebGpu"
local schemes = wezterm.get_builtin_color_schemes()
if not schemes[config.color_scheme] then
  config.color_scheme = "Banana Blueberry"
end
return config
EOF
  fi  
  
  # 10. Finish Up
  # -----------------------------------------------------
  verify_install
  echo ""
  echo "Giocoso installation completed. You can close this terminal now."
  reset
  rm -f "$INSTALLERFILE"
  exit 0
else      # They said not to proceed
  clear
  echo ""
  echo "Giocoso installation aborted. You can close this terminal now."
  exit_program
fi

# Failsafe cleanup
# -----------------------------------------------------
reset
rm -f "$INSTALLERFILE"
exit 0