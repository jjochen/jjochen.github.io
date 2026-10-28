#!/usr/bin/env bash
set -euo pipefail

repository_path=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temporary_path=$(mktemp -d)
trap 'rm -rf "$temporary_path"' EXIT
prepare_script="$repository_path/tool/prepare_pages.sh"
fixture_path="$temporary_path/fixture"
mkdir -p "$fixture_path/assets" "$fixture_path/canvaskit"
for file in index.html main.dart.js flutter.js flutter_bootstrap.js \
  manifest.json assets/AssetManifest.bin assets/FontManifest.json \
  canvaskit/canvaskit.js canvaskit/canvaskit.wasm; do
  printf 'fixture\n' > "$fixture_path/$file"
done
printf '<base href="/antivirus-flutter/">\n' > "$fixture_path/index.html"
tar --create --gzip --directory "$fixture_path" --file "$temporary_path/valid.tar.gz" .

expect_failure() {
  if bash "$prepare_script" "$1" "$temporary_path/rejected" > "$temporary_path/error.log" 2>&1; then
    echo "Unexpectedly accepted archive $1." >&2
    exit 1
  fi
  test ! -e "$temporary_path/rejected"
}

bash "$prepare_script" "$temporary_path/valid.tar.gz" "$temporary_path/with-app"
cmp "$fixture_path/main.dart.js" "$temporary_path/with-app/antivirus-flutter/main.dart.js"
bash "$prepare_script" - "$temporary_path/homepage-only"
test ! -e "$temporary_path/homepage-only/antivirus-flutter"
while IFS= read -r file; do
  case "$file" in
    .github/*|tool/*) continue ;;
  esac
  git -C "$repository_path" show "HEAD:$file" | cmp - "$temporary_path/with-app/$file"
  git -C "$repository_path" show "HEAD:$file" | cmp - "$temporary_path/homepage-only/$file"
done < <(git -C "$repository_path" ls-files)
test ! -e "$temporary_path/with-app/.github"
test ! -e "$temporary_path/with-app/tool"

# Missing files, an incorrect subpath, source maps, and corrupt archives fail.
mv "$fixture_path/main.dart.js" "$temporary_path/main.dart.js"
tar --create --gzip --directory "$fixture_path" --file "$temporary_path/missing.tar.gz" .
expect_failure "$temporary_path/missing.tar.gz"
mv "$temporary_path/main.dart.js" "$fixture_path/main.dart.js"
printf '<base href="/">\n' > "$fixture_path/index.html"
tar --create --gzip --directory "$fixture_path" --file "$temporary_path/base.tar.gz" .
expect_failure "$temporary_path/base.tar.gz"
printf '<base href="/antivirus-flutter/">\n' > "$fixture_path/index.html"
printf 'source map\n' > "$fixture_path/main.dart.js.map"
tar --create --gzip --directory "$fixture_path" --file "$temporary_path/maps.tar.gz" .
expect_failure "$temporary_path/maps.tar.gz"
rm "$fixture_path/main.dart.js.map"
printf 'invalid gzip\n' > "$temporary_path/corrupt.tar.gz"
expect_failure "$temporary_path/corrupt.tar.gz"

# An archive cannot escape the app subpath or link to other website files.
tar --create --gzip --directory "$fixture_path" \
  --transform='s|^main.dart.js$|../index.html|' \
  --file "$temporary_path/traversal.tar.gz" main.dart.js
expect_failure "$temporary_path/traversal.tar.gz"
tar --create --gzip --directory "$fixture_path" \
  --transform='s|^main.dart.js$|/index.html|' \
  --file "$temporary_path/absolute.tar.gz" main.dart.js
expect_failure "$temporary_path/absolute.tar.gz"
ln -s ../index.html "$fixture_path/link"
tar --create --gzip --directory "$fixture_path" --file "$temporary_path/link.tar.gz" .
expect_failure "$temporary_path/link.tar.gz"

if bash "$prepare_script" - "$temporary_path/with-app" > "$temporary_path/error.log" 2>&1; then
  echo 'Unexpectedly accepted an existing output directory.' >&2
  exit 1
fi
cmp "$repository_path/index.html" "$temporary_path/with-app/index.html"
echo 'Pages staging tests passed; existing website content is preserved.'
