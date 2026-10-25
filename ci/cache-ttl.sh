#!/bin/sh
# Usage: cache-ttl.sh <dir>. Empties a CI cache dir once it is over an hour old, so it never goes stale or grows unbounded.
set -e
if [ -z "$(find "$1/.created" -mmin -60 2>/dev/null)" ]; then
  rm -rf "$1"
  mkdir -p "$1"
  touch "$1/.created"
fi
