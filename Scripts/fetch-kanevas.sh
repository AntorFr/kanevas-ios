#!/bin/sh
# Provisions a read-only clone of AntorFr/kanevas OUTSIDE this repository tree and prints its path on stdout
# (everything else goes to stderr). Its dist/public is the web build shared by the pod (Scripts/build-kanevas-web.sh), never built here. Used by the UI test harness when KANEVAS_SRC is unset.
# Needs network, git, node, npm. Any failure exits 3 (bench problem, not a red test).
set -eu

dest="${KANEVAS_CLONE_DIR:-${TMPDIR:-/tmp}/kanevas-ios-stub-src}"
url="${KANEVAS_REPO_URL:-https://github.com/AntorFr/kanevas}"
share="${KANEVAS_WEB_DIR:-/sdlc/runs/kanevas-web}"
repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"

fail() { echo "fetch-kanevas: $1" >&2; exit 3; }

case "$dest" in "$repo_root"|"$repo_root"/*) fail "destination $dest is inside the repository tree" ;; esac
command -v git >/dev/null 2>&1 || fail "git not found"
command -v node >/dev/null 2>&1 || fail "node not found"
command -v npm >/dev/null 2>&1 || fail "npm not found"

if [ ! -d "$dest/.git" ]; then
  rm -rf "$dest"
  git clone --quiet --depth 1 "$url" "$dest" >&2 || fail "git clone $url failed"
fi
# The stub serves the map and the sheets from the web build (else every page is « Page introuvable. »). It is built in the
# pod by Scripts/build-kanevas-web.sh (cargo, wasm-pack: not on the Mac) and shared in $share; this script only copies it.
rev="$(cat "$share/REVISION" 2>/dev/null || true)"
[ -f "$share/public/index.html" ] && [ -n "$rev" ] || fail "no shared web build in $share (public/index.html, REVISION): run Scripts/build-kanevas-web.sh in the pod"
if [ "$(cat "$dest/dist/REVISION" 2>/dev/null || true)" != "$rev" ]; then
  # same Kanevas commit for the server code and the web build
  (cd "$dest" && git fetch --quiet --depth 1 origin "$rev" >&2 && git checkout --quiet --force "$rev" >&2) || fail "cannot check out Kanevas $rev"
  (cd "$dest" && npm ci --no-audit --no-fund >&2) || fail "npm ci failed"
  rm -rf "$dest/dist/public"
  mkdir -p "$dest/dist"
  cp -R "$share/public" "$dest/dist/public" || fail "cannot copy $share/public"
  echo "$rev" > "$dest/dist/REVISION"
fi
echo "$dest"
