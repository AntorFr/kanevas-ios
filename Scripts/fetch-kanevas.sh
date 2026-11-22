#!/bin/sh
# Provisions a read-only clone of AntorFr/kanevas OUTSIDE this repository tree and prints its path on stdout
# (everything else goes to stderr). The clone is built (`npm run build`) when dist/public is missing. Used by the UI test harness when KANEVAS_SRC is unset.
# Needs network, git, node, npm. Any failure exits 3 (bench problem, not a red test).
set -eu

dest="${KANEVAS_CLONE_DIR:-${TMPDIR:-/tmp}/kanevas-ios-stub-src}"
url="${KANEVAS_REPO_URL:-https://github.com/AntorFr/kanevas}"
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
if [ ! -d "$dest/node_modules/tsx" ]; then
  (cd "$dest" && npm ci --no-audit --no-fund >&2) || fail "npm ci failed"
fi
if [ ! -f "$dest/dist/public/index.html" ]; then
  # The stub serves the map and the sheets from the web build; without it every page is « Page introuvable. ».
  # The web build needs rust/pkg (WebAssembly): built first when absent (needs cargo and wasm-pack).
  if [ ! -d "$dest/rust/pkg" ]; then
    (cd "$dest" && npm run build:wasm >&2) || fail "npm run build:wasm failed (cargo / wasm-pack on the bench?)"
  fi
  (cd "$dest" && npm run build >&2) || fail "npm run build failed"
  [ -f "$dest/dist/public/index.html" ] || fail "npm run build left no dist/public/index.html"
fi
echo "$dest"
