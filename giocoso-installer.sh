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
HOTKEY=11 DRAWLINES=2 MAINTEXT=15 LOGO=6 INFOTEXT=11 SPINNER=12 ALERT=1

# Determine if the user has invoked the installer with a specific distro
# or release flavour in mind
while getopts "v:d:" opt; do
	case "$opt" in
	  v)  GIORELEASE="$OPTARG";;
	  d)  GIODISTRO="$OPTARG";;
	esac
done

if [[ $GIORELEASE == "beta" ]]; then 
  REMOTESOURCE="https://raw.githubusercontent.com/dizwell/giocoso4/beta"   # Everything is fetched from GitHub: beta branch (work in progress)...
else
  REMOTESOURCE="https://raw.githubusercontent.com/dizwell/giocoso4/main"   # ...or main (releases)
fi

function exit_program {
rm -f gio4inst >/dev/null 2>&1
reset
exit 1
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
}

function downloads {
# 4. Fetch Giocoso components: BIN files first
components=(gioadvsql.sh gioart.sh gioaudtst.sh giobkpdb.sh giocolour.sh gioconfconstruct.sh giocontrol.sh giocount.sh giodefsrch.sh giodirselect.sh gioexcludes.sh gioexempts.sh giofilter.sh giofunctions.sh gioglobresume.sh giomenudraw.sh giomenuoptions.sh giominifilter.sh giominip.sh giomplay.sh giooscheck.sh giooutput.sh gioparse.sh giophoneme.sh gioplay.sh gioplaylist.sh giopsink.sh gioqrydel.sh giorefreshdb.sh gioretnote.sh giorptadvsql.sh giorptaggstats.sh giorptallrecs.sh giorptdevos.sh giorptexcludes.sh giorptlastplayed.sh giorptplayhist.sh giorpttopcomp.sh giospin.sh giosql.sh giotput.sh)
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
  # The main script lives in the program folder (so git pull keeps it current); /usr/local/bin just links to it
  sudo rm -f "/usr/local/bin/giocoso4.sh" "/usr/local/bin/giocoso" 2>/dev/null
  sudo ln -s "$NEWCONF/giocoso4.sh" "/usr/local/bin/giocoso4.sh"
  sudo ln -s "$NEWCONF/giocoso4.sh" "/usr/local/bin/giocoso"
  sudo sh -c 'printf "#!/usr/bin/env bash\ngiocoso --play\n" >/usr/local/bin/minig'; sudo chmod +x /usr/local/bin/minig
  
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
  # The main script lives in the program folder (so git pull keeps it current); /usr/bin just links to it
  sudo rm -f "/usr/bin/giocoso4.sh" "/usr/bin/giocoso" 2>/dev/null
  sudo ln -s "$NEWCONF/giocoso4.sh" "/usr/bin/giocoso4.sh"
  sudo ln -s "$NEWCONF/giocoso4.sh" "/usr/bin/giocoso"
  sudo sh -c 'printf "#!/usr/bin/env bash\ngiocoso --play\n" >/usr/bin/minig'; sudo chmod +x /usr/bin/minig

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
if [[ -x /opt/homebrew/bin/bash && -x /opt/homebrew/bin/wezterm ]]; then
  bashPath="/opt/homebrew/bin/bash"
  weztermPath="/opt/homebrew/bin/wezterm"
elif [[ -x /usr/local/bin/bash && -x /usr/local/bin/wezterm ]]; then
  bashPath="/usr/local/bin/bash"
  weztermPath="/usr/local/bin/wezterm"
else
  bashPath="/opt/local/bin/bash"
  weztermPath="/opt/local/bin/wezterm"
fi

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
dialog --title " Software Components Completed " --msgbox "\\n\\nAll Giocoso's components have now been installed successfully.\\n\\nPress OK to quit back to the command line." 12 70
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
tput cup 19 4; tput setaf $ALERT; read -s -n 1 -p "Do you wish to proceed? (y/n): " response

if [[ "$response" == [Yy]* ]]; then
  clear; print_header; tput setaf $MAINTEXT; tput cup 6 0
  tput cup 6 4; echo -e "Checking your network connection is working..."
  if ! ping -c1 -W1 "1.1.1.1" >/dev/null 2>&1; then
    tput clear; print_header
    tput cup 6 4; tput setaf $ALERT; echo -e "Sadly, you do not appear to be able to reach the Internet.\n\nThis is a requirement for the Giocoso installation." | fold -s -w 76 | sed '2,$s/^/    /'
    tput cup 10 4; tput setaf $MAINTEXT; read -n 1 -p "Quitting in the meantime. Press a key to exit."
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
  wget -q "$REMOTESOURCE/bin/giooscheck.sh" -O "$NEWCONF/bin/giooscheck.sh"
  source "$NEWCONF/bin/giooscheck.sh" install $GIODISTRO       # Triggers a check of software dependencies and *fixes* them
  downloads
  if [[ $OS == "DARWIN" ]]; then
    chown -R $USERNAME:staff "$NEWCONF" 2>/dev/null
  else
    chown -R $USERNAME:$USERNAME "$NEWCONF" 2>/dev/null
  fi
  
  # 5. Download the various Dialog configuration files
  # -----------------------------------------------------
  wget -q "$REMOTESOURCE/txt/standard.conf" -O "$NEWCONF/txt/standard.conf"
  wget -q "$REMOTESOURCE/txt/red.conf" -O "$NEWCONF/txt/red.conf"
  wget -q "$REMOTESOURCE/txt/green.conf" -O "$NEWCONF/txt/green.conf"
  wget -q "$REMOTESOURCE/txt/yellow.conf" -O "$NEWCONF/txt/yellow.conf"
  wget -q "$REMOTESOURCE/txt/magenta.conf" -O "$NEWCONF/txt/magenta.conf"

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
  
  # 9. Create minig launcher
  # -----------------------------------------------------  
  if [[ $OS == "DARWIN" ]]; then
    if ! [[ -f /usr/local/bin/minig ]]; then 
      echo -e '#!/usr/bin/env bash\ngiocoso --play' | sudo tee /usr/local/bin/minig > /dev/null
      sudo chmod +x /usr/local/bin/minig
    fi
  else
    if ! [[ -f /usr/bin/minig ]]; then
      echo -e '#!/usr/bin/env bash\ngiocoso --play' | sudo tee /usr/bin/minig > /dev/null
      sudo chmod +x /usr/bin/minig
    fi
  fi
  
  # 10. Finish Up
  # -----------------------------------------------------
  echo ""
  echo "Giocoso installation completed. You can close this terminal now."
  reset
  rm -f gio4inst
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
rm -f gio4inst
exit 0