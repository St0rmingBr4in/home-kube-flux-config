#!/bin/sh
# Usage: sh ci/step-timeout.sh <seconds>, first in a step. Woodpecker YAML has no per-step timeout,
# so a hung step would otherwise run until the repo-wide 60-minute limit. Kills the step's shell.
step_shell=$PPID
( sleep "$1"; echo "step-timeout: killed after $1s" >&2; kill -TERM "$step_shell" ) &
