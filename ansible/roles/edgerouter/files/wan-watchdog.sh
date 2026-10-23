#!/bin/bash
# Orange can drop the WAN session while the DHCP lease looks valid, and dhclient would wait
# up to 3 days for it to expire. Managed by Ansible (edgerouter role), do not edit on the router.
set -u

IFACE=eth5.832
TARGETS="1.1.1.1 8.8.8.8 9.9.9.9"
FIRST_RETRY_MIN=5
MAX_BACKOFF_MIN=60
STATE=/tmp/wan-watchdog.state
OP=/opt/vyatta/bin/vyatta-op-cmd-wrapper

log() { logger -t wan-watchdog "$*"; }

wan_up() {
    local t
    for t in $TARGETS; do
        ping -c 2 -W 3 -I "$IFACE" "$t" >/dev/null 2>&1 && return 0
    done
    return 1
}

save_state() { echo "$1 $2" > "$STATE" || log "cannot write $STATE"; }

failed_min=0
backoff_min=$FIRST_RETRY_MIN
if [ -e "$STATE" ]; then
    read -r f b < "$STATE"
    case "${f:-x}${b:-x}" in
        *[!0-9]*) log "corrupt state '$f $b' in $STATE, resetting" ;;
        *) failed_min=$f; backoff_min=$b ;;
    esac
fi

if wan_up; then
    [ "$failed_min" -gt 0 ] && log "WAN reachable again on $IFACE"
    save_state 0 "$FIRST_RETRY_MIN"
    exit 0
fi

failed_min=$((failed_min + 1))
if [ "$failed_min" -ge "$backoff_min" ]; then
    log "WAN unreachable for ${failed_min} min, releasing and renewing DHCP on $IFACE"
    out=$($OP release dhcp interface "$IFACE" 2>&1) || log "DHCP release failed: $out"
    sleep 5
    if out=$($OP renew dhcp interface "$IFACE" 2>&1); then
        log "DHCP renew issued on $IFACE"
    else
        log "DHCP renew failed: $out"
    fi
    # Back off: Orange rate-limits clients that hammer its DHCP servers.
    backoff_min=$((backoff_min * 2))
    [ "$backoff_min" -gt "$MAX_BACKOFF_MIN" ] && backoff_min=$MAX_BACKOFF_MIN
    failed_min=0
fi
save_state "$failed_min" "$backoff_min"
