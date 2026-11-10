#!/usr/bin/env bash
####################################################################
#
# gioart: routine for processing album art into a displayable,
# captioned piece of artwork.
#
# Passed parameters: $1=Composer name
#                    $2=Composition name
#
# Note: Artsize must be determined from the configuration file.
#
####################################################################

displaycomp="$1"
displaywork="$2"
# Giocoso's magick has no fontconfig, so the caption font is passed as a font file, not a font name
if [[ $OSFAMILY != "MACOS" ]]; then 
  captionfont=$(fc-list -f '%{file}\n' ':family=Libre Baskerville:style=Regular' | head -1)
  if [[ -z $captionfont ]]; then captionfont=$(fc-list -f '%{file}\n' ':family=Liberation Serif:style=Regular' | head -1); fi
  if [[ -z $captionfont ]]; then captionfont=$(fc-match -f '%{file}' 'Courier'); fi
elif [[ $OSFAMILY == "MACOS" ]]; then
  for captionfont in /System/Library/Fonts/Palatino.ttc /System/Library/Fonts/Supplemental/Palatino.ttc; do
    [[ -f $captionfont ]] && break
  done
fi

function hextorgb {
# A simple function that takes a colour input value in Hex format (e.g., #34AC89)
# and derives decimal values for Red, Green and Blue components of that colour
HEXCOLOR=$(echo "${1^^}" | $SEDPROG 's/#//g' 2>/dev/null)

HEX1=$(echo $HEXCOLOR | cut -c-2)
HEX2=$(echo $HEXCOLOR | cut -c3-4)
HEX3=$(echo $HEXCOLOR | cut -c5-6)

RXD=$(echo "ibase=16; $HEX1" | bc)
GRN=$(echo "ibase=16; $HEX2" | bc)
BLU=$(echo "ibase=16; $HEX3" | bc)
}

function luminance {
# Convert any RGB colour code into a luminance value
ALBUMRED=$1
ALBUMGRN=$2
ALBUMBLU=$3

# Convert RGB value to a 0-100 range. Multiply by 100 to return numbers in the
# 0 to 100 range, rather than decimals.
((ALBUMRED=ALBUMRED * 100 / 255))
((ALBUMGRN=ALBUMGRN * 100 / 255))
((ALBUMBLU=ALBUMBLU * 100 / 255))

# Calculate the luminance using the RGB values. Luminance therefore has values ranging between 0 and 100.
L1=$(echo "$ALBUMRED * 0.2126" | bc -l)
L2=$(echo "$ALBUMGRN * 0.7152" | bc -l)
L3=$(echo "$ALBUMBLU * 0.0722" | bc -l)
L4=$(echo "$L1+$L2+$L3" | bc -l)

LUMINANCE=$(round "$L4/1" 0)

if [[ $LUMINANCE -gt 56 ]]; then
  textcolor="#140014" # A very dark purple, practically black
else
  textcolor="#FFFFCC" # A very pale yellow, practically white
fi
}

if [[ ${#displaywork} -gt 35 ]]; then
  displaywork="${displaywork:0:35}…"
fi

captiontext="$displaycomp: \n$displaywork"

if [[ ${#captiontext} -gt 80 ]]; then
  echo -e "\n${captiontext:0:80}…" > "$CONFDIR/txt/caption.txt"
else
  echo -e "\n$captiontext" > "$CONFDIR/txt/caption.txt"
fi

# If the album art is internally CMYK, convert it to sRGB, because CMYK files can't be displayed by img2sixel
if [[ $($MAGICK identify -format "%[colorspace]" "$CONFDIR/art/albumart.jpg" 2>/dev/null) == "CMYK" ]]; then
  $MAGICK "$CONFDIR/art/albumart.jpg" -colorspace sRGB "$CONFDIR/art/albumart.jpg" 2>/dev/null
fi

# Analyze the album art to arrive at a caption panel background colour
ALBUMCAPTION=$(cat "$CONFDIR/txt/caption.txt")

# Analyze the album art to arrive at a caption panel background colour
$MAGICK "$CONFDIR/art/albumart.jpg" -scale 50x50! -depth 8 +dither -colors 3 -format "%c" histogram:info: 2>/dev/null | $SEDPROG -n 's/^[ ]*\(.*\):.*[#]\([0-9a-fA-F]*\) .*$/\1,#\2/p' 2>/dev/null | sort -r -n -k 1 -t "," > "$CONFDIR/txt/histogram.txt"
CAPTIONBACK=$(cat "$CONFDIR/txt/histogram.txt" | tail -1 | awk -F ',' '{print $2}' | head -c 7); if [[ -z $CAPTIONBACK ]]; then CAPTIONBACK="#808080"; fi
hextorgb $CAPTIONBACK     # Derives decimal values for RED, GRN and BLU
luminance $RXD $GRN $BLU  # Uses those values to calculate luminance
CAPTIONTEXT=$textcolor

# Finally create the displayable album art+caption
CAPHEIGHT=$(echo $ARTSIZE | awk -Fx '{print $1}'); CAPHEIGHT=$((CAPHEIGHT/10))
POINTSIZE=$((CAPHEIGHT / 10)); POINTSIZE=$((POINTSIZE * 4))
CAPSIZE="$(echo $ARTSIZE | awk -Fx '{print $1}')x$CAPHEIGHT"

$MAGICK "$CONFDIR/art/albumart.jpg" -strip -resize "${ARTSIZE}x${ARTSIZE}!" "$CONFDIR/art/albumart.jpg" 2>/dev/null
$MAGICK -size "$CAPSIZE" -background "$CAPTIONBACK" -font "$captionfont" -pointsize "$POINTSIZE" -gravity center -fill "$CAPTIONTEXT" caption:"$ALBUMCAPTION" "$CONFDIR/art/nowplaying.jpg" 2>/dev/null
$MAGICK "$CONFDIR/art/albumart.jpg" "$CONFDIR/art/nowplaying.jpg" -append "$CONFDIR/art/albumart.jpg" 2>/dev/null