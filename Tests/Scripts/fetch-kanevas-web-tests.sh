#!/bin/sh
# Feature tests of the pinned Kanevas page (kanevas-ios-web-epingle), written from the need, not from the script.
# Runs on any host with sh, node (>= 20), curl, tar and a SHA-256 tool. No test touches the real network:
# a loopback server plays the Release download base (KANEVAS_WEB_BASE_URL).
# Usage: sh Tests/Scripts/fetch-kanevas-web-tests.sh      Exit 0 = all green, 1 = at least one red.
set -u

root="$(cd "$(dirname "$0")/../.." && pwd -P)"
tmp="$(mktemp -d)"
srv_pid=""
cleanup() { [ -n "$srv_pid" ] && kill "$srv_pid" 2>/dev/null; rm -rf "$tmp"; }
trap cleanup EXIT

fails=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1 -- $2"; fails=$((fails + 1)); }
# check <name> <expected exit> <actual exit>
exit_is() { if [ "$3" = "$2" ]; then ok "$1"; else bad "$1" "exit expected $2, got $3"; fi; }
# stderr_has <name> <literal text> <file>
says() { if grep -qi -- "$2" "$3"; then ok "$1"; else bad "$1" "stderr lacks '$2': $(cat "$3")"; fi; }

sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d ' ' -f 1; else shasum -a 256 "$1" | cut -d ' ' -f 1; fi; }

# --- fake Release tree: $tmp/www/<tag>/kanevas-web-<bare>.tar.gz(.sha256)
www="$tmp/www"; mkdir -p "$www"
make_release() { # <tag> : a valid archive whose VERSION file says the bare version
  tag="$1"; bare="${tag#v}"; src="$tmp/src-$bare"; mkdir -p "$src" "$www/$tag"
  echo "// stub launcher" > "$src/lancer-bouchon.mjs"; echo "$bare" > "$src/VERSION"
  tar -czf "$www/$tag/kanevas-web-$bare.tar.gz" -C "$src" .
  echo "$(sha "$www/$tag/kanevas-web-$bare.tar.gz")  kanevas-web-$bare.tar.gz" > "$www/$tag/kanevas-web-$bare.tar.gz.sha256"
}
make_release v9.9.9
make_release v1.0.0
make_release v2.0.0
make_release v0.50.0
# bad sum: archive present, sum file says something else
make_release v3.0.0
echo "0000000000000000000000000000000000000000000000000000000000000000  kanevas-web-3.0.0.tar.gz" > "$www/v3.0.0/kanevas-web-3.0.0.tar.gz.sha256"
# archive without its sum file
make_release v4.0.0; rm "$www/v4.0.0/kanevas-web-4.0.0.tar.gz.sha256"

cat > "$tmp/serve.mjs" <<'JS'
import http from 'node:http'; import fs from 'node:fs'; import path from 'node:path';
const dir = process.argv[2];
const s = http.createServer((q, r) => {
  const f = path.join(dir, decodeURIComponent(q.url));
  if (fs.existsSync(f) && fs.statSync(f).isFile()) { r.writeHead(200); fs.createReadStream(f).pipe(r); }
  else { r.writeHead(404); r.end('nope'); }
});
s.listen(0, '127.0.0.1', () => { fs.writeFileSync(process.argv[3], String(s.address().port)); });
JS
node "$tmp/serve.mjs" "$www" "$tmp/port" & srv_pid=$!
i=0; while [ ! -s "$tmp/port" ] && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
[ -s "$tmp/port" ] || { echo "cannot start the fake Release server"; exit 1; }
base="http://127.0.0.1:$(cat "$tmp/port")"

fetch() { # <cache> <args...> ; sets rc, out, err
  c="$1"; shift
  KANEVAS_WEB_BASE_URL="$base" KANEVAS_WEB_CACHE="$c" sh "$root/Scripts/fetch-kanevas-web.sh" "$@" >"$tmp/out" 2>"$tmp/err"; rc=$?
}

# B-7/P-6: nominal, the page is fetched, checked, unpacked outside the repository, its path is the only stdout line
cache="$tmp/cache1"; fetch "$cache" v9.9.9
exit_is "nominal_exit_0" 0 "$rc"
[ "$(cat "$tmp/out")" = "$cache/v9.9.9" ] && ok "nominal_prints_cache_folder_only" || bad "nominal_prints_cache_folder_only" "stdout: $(cat "$tmp/out")"
[ "$(cat "$cache/v9.9.9/VERSION" 2>/dev/null)" = "9.9.9" ] && ok "nominal_unpacks_archive_with_VERSION" || bad "nominal_unpacks_archive_with_VERSION" "no VERSION 9.9.9"
[ -f "$cache/v9.9.9/lancer-bouchon.mjs" ] && ok "nominal_unpacks_launcher" || bad "nominal_unpacks_launcher" "no lancer-bouchon.mjs"
case "$cache" in "$root"/*) bad "cache_outside_repo" "inside repo";; *) ok "cache_outside_repo";; esac

# bords: second run is served from the cache, with the network gone
KANEVAS_WEB_BASE_URL="http://127.0.0.1:1" KANEVAS_WEB_CACHE="$cache" sh "$root/Scripts/fetch-kanevas-web.sh" v9.9.9 >"$tmp/out" 2>"$tmp/err"; rc=$?
exit_is "cached_version_needs_no_network" 0 "$rc"
[ "$(cat "$tmp/out")" = "$cache/v9.9.9" ] && ok "cached_version_prints_same_folder" || bad "cached_version_prints_same_folder" "stdout: $(cat "$tmp/out")"

# bords: "1.0.0" is not the Release tag "v1.0.0": no archive, the cause is named
fetch "$tmp/cache1b" 1.0.0; exit_is "tag_without_v_is_another_tag_without_archive" 1 "$rc"
says "unknown_tag_names_no_archive" "no archive" "$tmp/err"

# échec: wrong sum
cache="$tmp/cache2"; fetch "$cache" v3.0.0
exit_is "wrong_sum_exits_1" 1 "$rc"
says "wrong_sum_names_checksum_mismatch" "checksum mismatch" "$tmp/err"
[ ! -f "$cache/v3.0.0/lancer-bouchon.mjs" ] && ok "wrong_sum_unpacks_nothing" || bad "wrong_sum_unpacks_nothing" "archive was unpacked"
[ -z "$(cat "$tmp/out")" ] && ok "wrong_sum_prints_no_folder" || bad "wrong_sum_prints_no_folder" "stdout: $(cat "$tmp/out")"

# échec: version without archive
fetch "$tmp/cache3" v7.7.7
exit_is "version_without_archive_exits_1" 1 "$rc"
says "version_without_archive_names_cause" "no archive" "$tmp/err"
fetch "$tmp/cache3b" v4.0.0
exit_is "archive_without_sum_exits_1" 1 "$rc"
says "archive_without_sum_names_no_archive" "no archive" "$tmp/err"

# échec: network absent -> 3 (and not 1: the pin is not wrong)
KANEVAS_WEB_BASE_URL="http://127.0.0.1:1" KANEVAS_WEB_CACHE="$tmp/cache4" sh "$root/Scripts/fetch-kanevas-web.sh" v9.9.9 >"$tmp/out" 2>"$tmp/err"; rc=$?
exit_is "network_absent_exits_3" 3 "$rc"
[ -s "$tmp/err" ] && ok "network_absent_says_something" || bad "network_absent_says_something" "silent"

# échec: node absent from the PATH -> 3
bin="$tmp/bin"; mkdir -p "$bin"
for t in sh dirname head tr cut mktemp mkdir rm curl tar sha256sum shasum cat mv; do p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$bin/$t"; done
KANEVAS_WEB_BASE_URL="$base" KANEVAS_WEB_CACHE="$tmp/cache5" PATH="$bin" "$bin/sh" "$root/Scripts/fetch-kanevas-web.sh" v9.9.9 >"$tmp/out" 2>"$tmp/err"; rc=$?
exit_is "node_absent_exits_3" 3 "$rc"
says "node_absent_names_node" "node" "$tmp/err"

# exclusion: changing the pinned file is the only gesture that changes the page served
repo="$tmp/repo"; mkdir -p "$repo/Scripts"; cp "$root/Scripts/fetch-kanevas-web.sh" "$repo/Scripts/"
echo "v1.0.0" > "$repo/KANEVAS_WEB_VERSION"
cache="$tmp/cache6"
KANEVAS_WEB_BASE_URL="$base" KANEVAS_WEB_CACHE="$cache" sh "$repo/Scripts/fetch-kanevas-web.sh" >"$tmp/out" 2>"$tmp/err"; rc=$?
exit_is "pin_v1_exits_0" 0 "$rc"
[ "$(cat "$cache/v1.0.0/VERSION" 2>/dev/null)" = "1.0.0" ] && ok "pin_v1_serves_1_0_0" || bad "pin_v1_serves_1_0_0" "stdout $(cat "$tmp/out")"
echo "v2.0.0" > "$repo/KANEVAS_WEB_VERSION"
KANEVAS_WEB_BASE_URL="$base" KANEVAS_WEB_CACHE="$cache" sh "$repo/Scripts/fetch-kanevas-web.sh" >"$tmp/out" 2>"$tmp/err"; rc=$?
[ "$(cat "$tmp/out")" = "$cache/v2.0.0" ] && [ "$(cat "$cache/v2.0.0/VERSION")" = "2.0.0" ] && ok "pin_v2_serves_2_0_0" || bad "pin_v2_serves_2_0_0" "rc=$rc stdout $(cat "$tmp/out")"
echo "v7.7.7" > "$repo/KANEVAS_WEB_VERSION"
KANEVAS_WEB_BASE_URL="$base" KANEVAS_WEB_CACHE="$cache" sh "$repo/Scripts/fetch-kanevas-web.sh" >"$tmp/out" 2>"$tmp/err"; rc=$?
exit_is "pin_without_archive_exits_1" 1 "$rc"

# the committed pin is one line naming a Release tag
[ "$(wc -l < "$root/KANEVAS_WEB_VERSION" | tr -d ' ')" = "1" ] && grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' "$root/KANEVAS_WEB_VERSION" && ok "pin_file_is_one_version_line" || bad "pin_file_is_one_version_line" "$(cat "$root/KANEVAS_WEB_VERSION")"

# exclusion: the old build chain is gone. Patterns are assembled so that this file does not match itself.
a="car"; b="go"; c="wasm"; d="-pack"; e="build-kanevas"; f="-web"; g=".kanevas"; h="-web"; k="KANEVAS"; l="_SRC"
cd "$root" || exit 1
for pat in "$a$b" "$c$d" "$e$f" "$g$h" "$k$l"; do
  hits="$(git grep -n -i -F -e "$pat" -- .sdlc.yaml Scripts Tests docs/tests.md 2>/dev/null | grep -v 'Tests/Scripts/fetch-kanevas-web-tests.sh')"
  [ -z "$hits" ] && ok "no_trace_of_$(echo "$pat" | tr -c 'A-Za-z0-9\n' '_')" || bad "no_trace_of_$pat" "$hits"
done
for gone in "Scripts/$e$f.sh" Scripts/fetch-kanevas.sh; do
  [ ! -e "$gone" ] && ok "removed_$(basename "$gone")" || bad "removed_$gone" "still there"
done
grep -q '^installation:' .sdlc.yaml && bad "no_installation_line_in_sdlc_yaml" "present" || ok "no_installation_line_in_sdlc_yaml"

echo; [ "$fails" -eq 0 ] && echo "all green" || echo "$fails red"
[ "$fails" -eq 0 ]
