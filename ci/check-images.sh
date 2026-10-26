#!/bin/sh
# Usage: check-images.sh <head-render-dir> [base-render-dir]
# Fails if an image in the head render has no linux/amd64 manifest. With a base render, only
# images new in head are checked: keeps Docker Hub's anonymous rate limit (shared with the cluster) untouched.
set -e
images() { grep -rhoE '^[[:space:]]*(- )?image: [^[:space:]]+' "$1" | sed -E 's/.*image: //' | tr -d "\"'" | sort -u; }

images "$1" > /tmp/images.head
if [ -n "$2" ]; then
  images "$2" > /tmp/images.base
  comm -13 /tmp/images.base /tmp/images.head > /tmp/images.check
else
  cp /tmp/images.head /tmp/images.check
fi
if [ ! -s /tmp/images.check ]; then
  echo "No new images to check."
  exit 0
fi

missing=0
while read -r img; do
  if crane digest --platform linux/amd64 "$img" >/dev/null 2>/tmp/crane.err; then
    echo "ok       $img"
  else
    echo "MISSING  $img: $(tail -1 /tmp/crane.err)"
    missing=1
  fi
done < /tmp/images.check
exit $missing
