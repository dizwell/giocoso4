#!/usr/bin/env bash
####################################################################
#
# giominip: A function to solicit input of an IP address for a remote PulseAudio 
# server, intended to be run on a mobile device with minimal screen capabilities
#
####################################################################
# 1. Fetch data: identifier (Tag), ipaddress (Item), and Status (on/off)
# The CASE statement checks if the database IP matches the current $PULSESERVER
mapfile -t menu_options < <("${PROCONN[@]}" -N -B -e "select identifier, ipaddress, case when ipaddress = '$PULSESERVER' then 'on' else 'off' end from pulsesinks limit 10;" | $SEDPROG 's/\t/\n/g' 2>/dev/null)

# 2. Display the Radiolist
CONFPULSE=$(dialog --backtitle "Giocoso PulseAudio Redirector" \
                   --title " PulseAudio Server Selector " \
                   --radiolist "Space to select, Enter to confirm:" 15 45 5 \
                   "${menu_options[@]}" \
                   2>&1 >/dev/tty)

exitStatus=$?

# 3. Update the config if they didn't Cancel
if [[ $exitStatus -eq 0 && -n "$CONFPULSE" ]]; then
  SELECTED_IP=$("${PROCONN[@]}" -N -B -e "select ipaddress from pulsesinks where identifier='$CONFPULSE' limit 1;")	
  if [[ -n "$SELECTED_IP" ]]; then
    $SEDPROG -i "s/^PULSESERVER=.*/PULSESERVER=$SELECTED_IP/" "$CONFDIR/txt/giocoso.conf" 2>/dev/null
    PULSESERVER="$SELECTED_IP"
  fi
fi