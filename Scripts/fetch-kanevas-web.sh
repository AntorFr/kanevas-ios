#!/bin/sh
# Fetches the pinned web archive of AntorFr/kanevas (AD-web-epingle-2), checks it, unpacks it OUTSIDE the repository
# tree into a cache per version and prints the unpacked folder on stdout (everything else goes to stderr).
# Usage: fetch-kanevas-web.sh [version]   (default: the line of KANEVAS_WEB_VERSION at the repository root)
# Exit: 0 done; 1 the pin is wrong ("checksum mismatch" or "no archive for <version>"); 3 bench problem
# (network, node, curl, tar or a sha256 tool missing, cache unwritable).
set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"
base="${KANEVAS_WEB_BASE_URL:-https://github.com/AntorFr/kanevas/releases/download}"
cache="${KANEVAS_WEB_CACHE:-${TMPDIR:-/tmp}/kanevas-ios-web}"

fail() { echo "fetch-kanevas-web: $2" >&2; exit "$1"; }

version="${1:-}"
if [ -z "$version" ]; then
  [ -f "$repo_root/KANEVAS_WEB_VERSION" ] || fail 3 "KANEVAS_WEB_VERSION missing at the repository root"
  version="$(head -n 1 "$repo_root/KANEVAS_WEB_VERSION" | tr -d '[:space:]')"
fi
[ -n "$version" ] || fail 1 "KANEVAS_WEB_VERSION is empty"
bare="${version#v}"
dest="$cache/$version"

case "$cache" in "$repo_root"|"$repo_root"/*) fail 3 "cache $cache is inside the repository tree" ;; esac
command -v node >/dev/null 2>&1 || fail 3 "node not found"
command -v curl >/dev/null 2>&1 || fail 3 "curl not found"
command -v tar >/dev/null 2>&1 || fail 3 "tar not found"
if command -v sha256sum >/dev/null 2>&1; then sum() { sha256sum "$1" | cut -d ' ' -f 1; }
elif command -v shasum >/dev/null 2>&1; then sum() { shasum -a 256 "$1" | cut -d ' ' -f 1; }
else fail 3 "no sha256sum or shasum"; fi

# A cache already unpacked and checked is reused, with no network.
if [ -f "$dest/.verifie" ] && [ -f "$dest/lancer-bouchon.mjs" ]; then echo "$dest"; exit 0; fi

mkdir -p "$cache" 2>/dev/null || fail 3 "cannot create the cache $cache"
work="$(mktemp -d "$cache/.tmp-$bare.XXXXXX" 2>/dev/null)" || fail 3 "cache $cache is not writable"
trap 'rm -rf "$work"' EXIT

name="kanevas-web-$bare.tar.gz"
# download <url> <file>: 0 done, 1 the file is not there (HTTP 404), 3 network or other failure.
download() {
  code="$(curl -sS -L -o "$2" -w '%{http_code}' "$1" 2>"$work/curl.err")" || return 3
  case "$code" in 200) return 0 ;; 404) return 1 ;; *) echo "HTTP $code for $1" >&2; return 3 ;; esac
}
download "$base/$version/$name" "$work/$name"; rc=$?
[ $rc -eq 1 ] && fail 1 "no archive for $version ($name absent from the Release $version of AntorFr/kanevas)"
[ $rc -eq 3 ] && fail 3 "download of $name failed: $(cat "$work/curl.err" 2>/dev/null)"
download "$base/$version/$name.sha256" "$work/$name.sha256"; rc=$?
[ $rc -eq 1 ] && fail 1 "no archive for $version ($name.sha256 absent from the Release $version of AntorFr/kanevas)"
[ $rc -eq 3 ] && fail 3 "download of $name.sha256 failed: $(cat "$work/curl.err" 2>/dev/null)"

expected="$(cut -d ' ' -f 1 "$work/$name.sha256" | head -n 1 | tr -d '[:space:]')"
actual="$(sum "$work/$name")"
[ -n "$expected" ] && [ "$expected" = "$actual" ] || fail 1 "checksum mismatch for $name (expected $expected, got $actual)"

mkdir "$work/unpacked" && tar -xzf "$work/$name" -C "$work/unpacked" 2>/dev/null || fail 3 "cannot unpack $name"
[ -f "$work/unpacked/lancer-bouchon.mjs" ] && [ -f "$work/unpacked/VERSION" ] || fail 1 "archive of $version has no lancer-bouchon.mjs / VERSION"
: > "$work/unpacked/.verifie"
rm -rf "$dest"
mv "$work/unpacked" "$dest" || fail 3 "cannot move the unpacked archive to $dest"
echo "$dest"
