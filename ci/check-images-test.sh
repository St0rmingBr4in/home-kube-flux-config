#!/bin/sh
# Self-check for check-images.sh with a fake crane: a rate limit is retried, a missing tag fails
# without retry, and a resolved digest ref is cached. Run as: sh ci/check-images-test.sh
set -eu
t=$(mktemp -d); export CACHE_DIR="$t/cache"; mkdir -p "$CACHE_DIR" "$t/bin" "$t/head"
cat > "$t/bin/crane" <<'FAKE'
#!/bin/sh
img=$4; f="$CACHE_DIR/calls.$(printf '%s' "$img" | tr -c 'a-z0-9' _)"
n=$(cat "$f" 2>/dev/null || echo 0); echo $((n + 1)) > "$f"
case "$img" in
  *limited*) [ "$n" -ge 1 ] && exit 0; echo "TOOMANYREQUESTS: slow down" >&2; exit 1 ;;
  *gone*) echo "MANIFEST_UNKNOWN" >&2; exit 1 ;;
  *) exit 0 ;;
esac
FAKE
printf '#!/bin/sh\n' > "$t/bin/sleep"  # backoff waits are skipped in the test
chmod +x "$t/bin/crane" "$t/bin/sleep"; export PATH="$t/bin:$PATH"
printf 'image: ok/a@sha256:1\nimage: x/limited:1\n' > "$t/head/a.yaml"
out=$(sh ci/check-images.sh "$t/head" 2>&1) || { echo "FAIL: retried run failed: $out"; exit 1; }
echo "$out" | grep -q 'rate-limited on x/limited:1' || { echo "FAIL: no retry"; exit 1; }
grep -qx 'ok/a@sha256:1' "$CACHE_DIR/images-ok" || { echo "FAIL: digest not cached"; exit 1; }
out=$(sh ci/check-images.sh "$t/head" 2>&1); echo "$out" | grep -q 'ok/a@sha256:1 (cached)' || { echo "FAIL: cache unused"; exit 1; }
printf 'image: x/gone:1\n' > "$t/head/a.yaml"
if sh ci/check-images.sh "$t/head" >/dev/null 2>&1; then echo "FAIL: missing tag passed"; exit 1; fi
[ "$(cat "$CACHE_DIR"/calls.x_gone_1)" = 1 ] || { echo "FAIL: missing tag was retried"; exit 1; }
rm -rf "$t"; echo "check-images OK"
