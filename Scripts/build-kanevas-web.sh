#!/bin/sh
# Runs in the POD (Linux: Rust, wasm32 target and wasm-pack are in the image), before xcodebuild.
# Builds the web of AntorFr/kanevas and shares ONLY its dist/public in a folder the bench (the Mac) sees:
#   ${KANEVAS_WEB_DIR:-/sdlc/runs/kanevas-web}/public   the web build
#   ${KANEVAS_WEB_DIR:-/sdlc/runs/kanevas-web}/REVISION the Kanevas commit it was built from
# Rebuilt only when the Kanevas HEAD differs from REVISION. node_modules is never shared (esbuild binaries are per OS).
# Any failure exits 3 (environment problem, not a red test).
set -eu

share="${KANEVAS_WEB_DIR:-/sdlc/runs/kanevas-web}"
url="${KANEVAS_REPO_URL:-https://github.com/AntorFr/kanevas}"

fail() { echo "build-kanevas-web: $1" >&2; exit 3; }

for tool in git node npm cargo wasm-pack; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool not found (this script runs in the pod, not on the Mac)"
done

head="$(git ls-remote "$url" HEAD | cut -f1)" || fail "git ls-remote $url failed"
[ -n "$head" ] || fail "no HEAD for $url"
if [ -f "$share/public/index.html" ] && [ "$(cat "$share/REVISION" 2>/dev/null)" = "$head" ]; then
  echo "build-kanevas-web: $share is up to date ($head)" >&2
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git clone --quiet "$url" "$work/src" >&2 || fail "git clone $url failed"
src="$work/src"
rev="$(git -C "$src" rev-parse HEAD)"
(cd "$src" && npm ci --no-audit --no-fund >&2) || fail "npm ci failed"
(cd "$src" && npm run build:wasm >&2) || fail "npm run build:wasm failed"
(cd "$src" && npm run build >&2) || fail "npm run build failed"
[ -f "$src/dist/public/index.html" ] || fail "npm run build left no dist/public/index.html"

mkdir -p "$share" || fail "cannot create $share"
rm -rf "$share/public.new"
cp -R "$src/dist/public" "$share/public.new" || fail "cannot copy dist/public to $share"
rm -rf "$share/public"
mv "$share/public.new" "$share/public"
echo "$rev" > "$share/REVISION"
echo "build-kanevas-web: $share built from $rev" >&2
