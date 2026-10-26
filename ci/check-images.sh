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

# A digest-pinned ref is immutable: one that resolved once stays valid, so it is remembered.
seen="${CACHE_DIR:-/tmp}/images-ok"
touch "$seen"

# Registries (lscr.io, Docker Hub) rate-limit anonymous lookups: retry those only, with backoff.
check() {
  for wait in 15 30 60 0; do
    crane digest --platform linux/amd64 "$1" >/dev/null 2>/tmp/crane.err && return 0
    grep -q TOOMANYREQUESTS /tmp/crane.err && [ "$wait" -gt 0 ] || return 1
    echo "rate-limited on $1, retrying in ${wait}s" >&2
    sleep "$wait"
  done
}

missing=0
while read -r img; do
  if grep -qxF "$img" "$seen"; then
    echo "ok       $img (cached)"
  elif check "$img"; then
    echo "ok       $img"
    case "$img" in *@sha256:*) echo "$img" >> "$seen" ;; esac
  else
    echo "MISSING  $img: $(tail -1 /tmp/crane.err)"
    missing=1
  fi
done < /tmp/images.check
exit $missing
