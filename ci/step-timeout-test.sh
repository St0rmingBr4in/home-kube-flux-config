#!/bin/sh
# Self-check for step-timeout.sh: a step running past its limit is killed (exit 143), and a step
# that finishes in time exits normally without waiting for the watchdog. Run as: sh ci/step-timeout-test.sh
set -u
printf 'set -e\nsh ci/step-timeout.sh 1\nsleep 5\necho too-late\n' | sh -e > /tmp/st.out 2>&1
rc=$?
if [ "$rc" != 143 ] || grep -q too-late /tmp/st.out; then
  echo "FAIL: hung step not killed (rc=$rc)"; cat /tmp/st.out; exit 1
fi
start=$(date +%s)
printf 'set -e\nsh ci/step-timeout.sh 30\necho done\n' | sh -e > /tmp/st.out 2>&1 || { echo "FAIL: normal step failed"; exit 1; }
[ $(( $(date +%s) - start )) -lt 5 ] || { echo "FAIL: normal step waited for the watchdog"; exit 1; }
echo "step-timeout OK"
