#!/bin/sh
# Self-check for cache-slot.sh: steps running at the same time get distinct slots, a freed slot
# is reused, and an expired slot is emptied. Run as: sh ci/cache-slot-test.sh (needs /cache writable).
set -eu
name="selftest-$(cat /proc/sys/kernel/random/uuid)"  # PIDs repeat across containers
hold() { sh -c ". ci/cache-slot.sh $name; echo \$CACHE_DIR > /tmp/$name.$1; sleep $2"; }
hold a 3 & sleep 0.5
hold b 3 & sleep 0.5
a=$(cat "/tmp/$name.a"); b=$(cat "/tmp/$name.b")
[ "$a" != "$b" ] || { echo "FAIL: concurrent steps share $a"; exit 1; }
wait
touch "$a/kept"
hold c 0
[ "$(cat "/tmp/$name.c")" = "$a" ] && [ -f "$a/kept" ] || { echo "FAIL: freed slot not reused as-is"; exit 1; }
touch -t "$(date -d @$(($(date +%s) - 7200)) +%Y%m%d%H%M)" "$a/.created"
hold d 0
[ ! -e "$a/kept" ] || { echo "FAIL: expired slot not emptied"; exit 1; }
rm -rf "/cache/$name" "/tmp/$name".*
echo "cache-slot OK"
