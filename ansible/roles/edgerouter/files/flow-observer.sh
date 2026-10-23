#!/bin/bash
# Samples conntrack to record which internal networks talk to each other, as input for
# VLAN segmentation rules. Managed by Ansible (edgerouter role), do not edit on the router.
set -u

LIVE=/tmp/flow-observer.tsv
SAVED=/config/flow-observer.tsv

log() { logger -t flow-observer "$*"; }
# Every failure exits before the hourly save, so a bad run never overwrites saved history.
fail() { log "$*"; rm -f "$LIVE.new"; exit 1; }

if [ ! -f "$LIVE" ] && [ -f "$SAVED" ]; then
    cp "$SAVED" "$LIVE" || fail "cannot restore $SAVED"
fi
if [ -e "$LIVE" ] && [ ! -r "$LIVE" ]; then
    fail "cannot read $LIVE"
fi

# Absolute path: cron's PATH does not include /usr/sbin.
entries=$(/usr/sbin/conntrack -L 2>/dev/null) || fail "conntrack -L failed"

# Columns: src dst proto dport, minutes seen, first seen, last seen (epoch).
if printf '%s\n' "$entries" | awk -v now="$(date +%s)" -v db="$LIVE" '
    function subnet(ip,  a) { split(ip, a, "."); return a[1] "." a[2] "." a[3] }
    function internal(ip) { return ip ~ /^192\.168\./ || ip ~ /^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\./ }
    BEGIN {
        while ((getline line < db) > 0) {
            split(line, f, "\t")
            seen[f[1]] = f[2]; first[f[1]] = f[3]; last[f[1]] = f[4]
        }
    }
    {
        src = ""; dst = ""; dport = ""
        for (i = 1; i <= NF; i++) {
            if (src == "" && $i ~ /^src=/) src = substr($i, 5)
            else if (dst == "" && $i ~ /^dst=/) dst = substr($i, 5)
            else if (dport == "" && $i ~ /^dport=/) dport = substr($i, 7)
        }
        if (!internal(src) || !internal(dst)) next
        # Same-subnet traffic never crosses the router, except traffic to the router itself.
        if (subnet(src) == subnet(dst) && dst !~ /\.1$/) next
        cur[src " " dst " " $1 " " (dport == "" ? "-" : dport)] = 1
    }
    END {
        for (k in cur) { seen[k]++; if (!(k in first)) first[k] = now; last[k] = now }
        out = db ".new"
        for (k in seen) printf "%s\t%d\t%d\t%d\n", k, seen[k], first[k], last[k] > out
    }'; then
    mv "$LIVE.new" "$LIVE" || fail "cannot update $LIVE"
else
    fail "failed to aggregate conntrack sample"
fi

# Copy to flash hourly so a reboot loses at most an hour of samples.
if [ "$(date +%M)" = "00" ]; then
    cp "$LIVE" "$SAVED" || fail "cannot save $SAVED"
fi
