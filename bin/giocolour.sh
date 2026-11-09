#!/usr/bin/env bash
####################################################################
#
# giocolour: routine for allowing program display elements to 
# be coloured in a user-configurable manner
#
####################################################################
CONFDIR="$HOME/.local/share/giocoso4"
CONFFILE="$CONFDIR/txt/giocoso.conf"
defaults=(11 2 15 6 11 12 1)

# Read parameters from an existing config file, if present
# ====================================================================
if [[ -f "$CONFFILE" ]]; then
  confhotkey=$(cat "$CONFFILE" | $GREPPROG -i HOTKEY= | awk -F= '{print $2}')
  confdrawlines=$(cat "$CONFFILE" | $GREPPROG -i DRAWLINES= | awk -F= '{print $2}')
  confmaintext=$(cat "$CONFFILE" | $GREPPROG -i MAINTEXT= | awk -F= '{print $2}')
  conflogo=$(cat "$CONFFILE" | $GREPPROG -i LOGO= | awk -F= '{print $2}')
  confinfotext=$(cat "$CONFFILE" | $GREPPROG -i INFOTEXT= | awk -F= '{print $2}')
  confspinner=$(cat "$CONFFILE" | $GREPPROG -i SPINNER= | awk -F= '{print $2}')
  confalert=$(cat "$CONFFILE" | $GREPPROG -i ALERT= | awk -F= '{print $2}')
fi

PALETTE_ROW1="\Z0 0 \Z1 1 \Z2  2 \Z3  3 \Z4  4 \Z5  5 \Z6  6 \Z7  7 \Zn"
PALETTE_ROW2="\Zb\Z0 8 \Zb\Z1 9 \Zb\Z2 10 \Zb\Z3 11 \Zb\Z4 12 \Zb\Z5 13 \Zb\Z6 14 \Zb\Z7 15 \Zn"
PALETTE="  Normal Colours: $PALETTE_ROW1\n  Bright Colours: $PALETTE_ROW2"

while true; do
    RESULT=$(dialog --colors --stdout \
        --backtitle "Giocoso Colour Picker" \
        --title " Select your colour palette " \
        --ok-label "OK" \
        --extra-button --extra-label "Reset to Defaults" \
        --form "\n\n$PALETTE\n\n" 20 80 7 \
        "Hotkey Initials (defaults to 11):"      1 1  "$confhotkey" 1 55 5 0 \
        "Box/Line-draw characters (defaults to 2):" 2 1  "$confdrawlines" 2 55 5 0 \
        "Menu option text (defaults to 15):"     3 1  "$confmaintext" 3 55 5 0 \
        "Program logo/boilerplate (defaults to 6):" 4 1  "$conflogo" 4 55 5 0 \
        "Informational text (defaults to 11):"  5 1  "$confinfotext" 5 55 5 0 \
        "Music notes & spinner (defaults to 12):" 6 1  "$confspinner" 6 55 5 0 \
        "Alert or danger text (defaults to 1):" 7 1  "$confalert" 7 55 5 0
    )

    ret=$?
    case $ret in
        0)  # OK pressed: save each value, but anything blank or not a whole number from 0 to 255
            # is silently replaced by that colour's default, so the form never shows a blank
            mapfile -t colour_array <<< "$RESULT"
            for i in 0 1 2 3 4 5 6; do
                if [[ ${colour_array[i]} =~ ^[0-9]{1,3}$ ]] && (( 10#${colour_array[i]} <= 255 )); then
                    colour_array[i]=$((10#${colour_array[i]}))
                else
                    colour_array[i]=${defaults[i]}
                fi
            done
            break
            ;;
        3)  # Extra button pressed = Reset to Defaults
            confhotkey=11
            confdrawlines=2
            confmaintext=15
            conflogo=6
            confinfotext=11
            confspinner=12
            confalert=1
            continue
            ;;
        1|255)  # Cancel or ESC: save all colours as their defaults
            colour_array=("${defaults[@]}")
            break
            ;;
    esac
done

# Assign array elements to meaningful variables
HOTKEY_VAL="${colour_array[0]}"
DRAWLINES_VAL="${colour_array[1]}"
MAINTEXT_VAL="${colour_array[2]}"
LOGO_VAL="${colour_array[3]}"
INFOTEXT_VAL="${colour_array[4]}"
SPINNER_VAL="${colour_array[5]}"
ALERT_VAL="${colour_array[6]}"

$SEDPROG -i \
  -e "s/^HOTKEY=.*/HOTKEY=$HOTKEY_VAL/" \
  -e "s/^DRAWLINES=.*/DRAWLINES=$DRAWLINES_VAL/" \
  -e "s/^MAINTEXT=.*/MAINTEXT=$MAINTEXT_VAL/" \
  -e "s/^LOGO=.*/LOGO=$LOGO_VAL/" \
  -e "s/^INFOTEXT=.*/INFOTEXT=$INFOTEXT_VAL/" \
  -e "s/^SPINNER=.*/SPINNER=$SPINNER_VAL/" \
  -e "s/^ALERT=.*/ALERT=$ALERT_VAL/" \
  "$CONFFILE" 2>/dev/null