#!/usr/bin/env bash
####################################################################
#
# giopsink: A function to enable Pulse Audio Sinks/IP address mappings.
#
####################################################################
CONFDIR="$HOME/.local/share/giocoso4"
source "$CONFDIR/bin/gioparse.sh"

function valid_ipv4 {
# True if $1 is four numbers from 0 to 255, separated by dots. Format only: it doesn't check that anything answers there.
local IFS=.; local -a o
[[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return 1
read -r -a o <<< "$1"
(( 10#${o[0]} <= 255 && 10#${o[1]} <= 255 && 10#${o[2]} <= 255 && 10#${o[3]} <= 255 ))
}

# 1. Fetch existing data into an array
current=()
while IFS=$'\t' read -r identifier ipaddress; do
  current+=("$identifier" "$ipaddress")
done < <("${PROCONN[@]}" -N -B -e "select identifier, ipaddress from pulsesinks limit 5;")

# 3. Build the Form
# Index 0=Room1 Name, 1=Room1 IP, 2=Room2 Name, 3=Room2 IP...
results=$(dialog --backtitle "Room Manager" --title " PulseAudio Server Mapping " \
    --form "Edit existing or add new sinks below:" 22 45 12 \
    "Sink 1:"  1 1 "${current[0]}"  1 10 25 0 \
    "IP:"      2 1 "${current[1]}"  2 10 25 0 \
    "Sink 2:"  4 1 "${current[2]}"  4 10 25 0 \
    "IP:"      5 1 "${current[3]}"  5 10 25 0 \
    "Sink 3:"  7 1 "${current[4]}"  7 10 25 0 \
    "IP:"      8 1 "${current[5]}"  8 10 25 0 \
    "Sink 4:" 10 1 "${current[6]}" 10 10 25 0 \
    "IP:"     11 1 "${current[7]}" 11 10 25 0 \
    "Sink 5:" 13 1 "${current[8]}" 13 10 25 0 \
    "IP:"     14 1 "${current[9]}" 14 10 25 0 \
    3>&1 1>&2 2>&3)

if [[ $? -eq 0 ]]; then
    # 4. Wipe and Re-build the table
    readarray -t lines <<< "$results"
    
    "${PROCONN[@]}" -e "delete from pulsesinks;" > /dev/null 2>&1
       
    # Loop through the pairs. Apostrophes in a name become underscores (Mum's room is saved as Mum_s room), and a
    # sink is only saved if its IP is a valid IPv4 address: four numbers from 0 to 255, separated by dots.
    BADSINKS=""
    for ((i=0; i<${#lines[@]}; i+=2)); do
        raw_name="${lines[$i]}"
        name="${raw_name:0:14}"; name="${name//\'/_}"
        ip="${lines[$i+1]}"
        if [[ -n "$name" ]]; then
          if valid_ipv4 "$ip"; then
            "${PROCONN[@]}" -e "insert into pulsesinks (identifier, ipaddress) values ('$name', '$ip');"
          else
            BADSINKS+="\n    $name"
          fi
        fi
    done
    if [[ -n $BADSINKS ]]; then
      dialog --backtitle "Room Manager" --title " Sinks Not Saved " --msgbox "\nThese sinks were not saved, because their IP address isn't a valid IPv4 address (four numbers from 0 to 255, separated by dots):\n$BADSINKS\n\nYou can add them again with a proper address." 16 70
    fi
fi