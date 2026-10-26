#!/bin/sh
# Usage: . ci/cache-slot.sh <name>. Sourced, so its lock (fd 9) lives as long as the step's shell.
# Sets CACHE_DIR to a slot of /cache/<name> that no other running step uses: parallel pipelines
# sharing one dir deleted it under each other on expiry and rewrote Terraform providers in use.
CACHE_DIR=
for slot in 0 1 2 3; do  # one per WOODPECKER_MAX_WORKFLOWS
  mkdir -p "/cache/$1/$slot"
  exec 9>"/cache/$1/$slot.lock"
  if flock -n 9; then CACHE_DIR=/cache/$1/$slot; break; fi
done
if [ -z "$CACHE_DIR" ]; then CACHE_DIR=/cache/$1/3; flock 9; fi  # fd 9 is slot 3's lock
# Empty the slot once it is over an hour old, so it never goes stale or grows unbounded.
if [ -z "$(find "$CACHE_DIR/.created" -mmin -60 2>/dev/null)" ]; then
  rm -rf "$CACHE_DIR"
  mkdir -p "$CACHE_DIR"
  touch "$CACHE_DIR/.created"
fi
