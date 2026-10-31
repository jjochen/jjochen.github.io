#!/usr/bin/env bash
set -euo pipefail

repository_path=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temporary_path=$(mktemp -d)
trap 'rm -rf "$temporary_path"' EXIT
prepare_script="$repository_path/tool/prepare_pages.sh"
fixture_path="$temporary_path/fixture/sample-site"
mkdir -p "$fixture_path/assets" "$fixture_path/canvaskit"
for file in index.html main.dart.js flutter.js flutter_bootstrap.js \
  manifest.json assets/AssetManifest.bin assets/FontManifest.json \
  canvaskit/canvaskit.js canvaskit/canvaskit.wasm; do
  printf 'fixture\n' > "$fixture_path/$file"
done
printf '<base href="/sample-site/">\n' > "$fixture_path/index.html"
tar --create --gzip --directory "$temporary_path/fixture" --file "$temporary_path/valid.tar.gz" sample-site

expect_failure() {
  if bash "$prepare_script" "$1" "$temporary_path/rejected" "${2:--}" > "$temporary_path/error.log" 2>&1; then
    echo "Unexpectedly accepted archive $1." >&2
    exit 1
  fi
  test ! -e "$temporary_path/rejected"
}

bash "$prepare_script" "$temporary_path/valid.tar.gz" "$temporary_path/with-app"
cmp "$fixture_path/main.dart.js" "$temporary_path/with-app/sample-site/main.dart.js"
bash "$prepare_script" - "$temporary_path/homepage-only"
test ! -e "$temporary_path/homepage-only/sample-site"
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
tar --create --gzip --directory "$temporary_path/fixture" --file "$temporary_path/missing.tar.gz" sample-site
expect_failure "$temporary_path/missing.tar.gz"
mv "$temporary_path/main.dart.js" "$fixture_path/main.dart.js"
printf '<base href="/">\n' > "$fixture_path/index.html"
tar --create --gzip --directory "$temporary_path/fixture" --file "$temporary_path/base.tar.gz" sample-site
expect_failure "$temporary_path/base.tar.gz"
printf '<base href="/sample-site/">\n' > "$fixture_path/index.html"
printf 'source map\n' > "$fixture_path/main.dart.js.map"
tar --create --gzip --directory "$temporary_path/fixture" --file "$temporary_path/maps.tar.gz" sample-site
expect_failure "$temporary_path/maps.tar.gz"
rm "$fixture_path/main.dart.js.map"
printf 'invalid gzip\n' > "$temporary_path/corrupt.tar.gz"
expect_failure "$temporary_path/corrupt.tar.gz"

# A bundle must have one directory and cannot replace the existing website.
tar --create --gzip --directory "$fixture_path" --file "$temporary_path/no-directory.tar.gz" .
expect_failure "$temporary_path/no-directory.tar.gz"
mkdir "$temporary_path/fixture/other-site"
tar --create --gzip --directory "$temporary_path/fixture" --file "$temporary_path/multiple.tar.gz" .
expect_failure "$temporary_path/multiple.tar.gz"
rmdir "$temporary_path/fixture/other-site"
mkdir "$temporary_path/collision"
cp -a "$fixture_path" "$temporary_path/collision/css"
tar --create --gzip --directory "$temporary_path/collision" --file "$temporary_path/collision.tar.gz" css
expect_failure "$temporary_path/collision.tar.gz"

# An archive cannot escape its subpath or link to other website files.
tar --create --gzip --directory "$temporary_path/fixture" \
  --transform='s|^sample-site/main.dart.js$|../index.html|' \
  --file "$temporary_path/traversal.tar.gz" sample-site/main.dart.js
expect_failure "$temporary_path/traversal.tar.gz"
tar --create --gzip --directory "$temporary_path/fixture" \
  --transform='s|^sample-site/main.dart.js$|/index.html|' \
  --file "$temporary_path/absolute.tar.gz" sample-site/main.dart.js
expect_failure "$temporary_path/absolute.tar.gz"
ln -s ../index.html "$fixture_path/link"
tar --create --gzip --directory "$temporary_path/fixture" --file "$temporary_path/link.tar.gz" sample-site
expect_failure "$temporary_path/link.tar.gz"

if bash "$prepare_script" - "$temporary_path/with-app" > "$temporary_path/error.log" 2>&1; then
  echo 'Unexpectedly accepted an existing output directory.' >&2
  exit 1
fi
cmp "$repository_path/index.html" "$temporary_path/with-app/index.html"

# Primary and nested preview bundles survive updates to either channel.
rm "$fixture_path/link"
mkdir -p "$temporary_path/preview/sample-site"
cp -a "$fixture_path" "$temporary_path/preview/sample-site/staging"
preview_path="$temporary_path/preview/sample-site/staging"
printf '<base href="/sample-site/staging/">\n' > "$preview_path/index.html"
printf 'preview-v1\n' > "$preview_path/main.dart.js"
tar --create --gzip --directory "$temporary_path/preview" --file "$temporary_path/preview-v1.tar.gz" sample-site
bash "$prepare_script" "$temporary_path/valid.tar.gz" "$temporary_path/both-v1" "$temporary_path/preview-v1.tar.gz"
cmp "$fixture_path/main.dart.js" "$temporary_path/both-v1/sample-site/main.dart.js"
cmp "$preview_path/main.dart.js" "$temporary_path/both-v1/sample-site/staging/main.dart.js"
cmp "$repository_path/index.html" "$temporary_path/both-v1/index.html"

printf 'preview-v2\n' > "$preview_path/main.dart.js"
tar --create --gzip --directory "$temporary_path/preview" --file "$temporary_path/preview-v2.tar.gz" sample-site
bash "$prepare_script" "$temporary_path/valid.tar.gz" "$temporary_path/new-preview" "$temporary_path/preview-v2.tar.gz"
cmp "$fixture_path/main.dart.js" "$temporary_path/new-preview/sample-site/main.dart.js"
cmp "$preview_path/main.dart.js" "$temporary_path/new-preview/sample-site/staging/main.dart.js"

printf 'primary-v2\n' > "$fixture_path/main.dart.js"
tar --create --gzip --directory "$temporary_path/fixture" --file "$temporary_path/primary-v2.tar.gz" sample-site
bash "$prepare_script" "$temporary_path/primary-v2.tar.gz" "$temporary_path/new-primary" "$temporary_path/preview-v2.tar.gz"
cmp "$fixture_path/main.dart.js" "$temporary_path/new-primary/sample-site/main.dart.js"
cmp "$preview_path/main.dart.js" "$temporary_path/new-primary/sample-site/staging/main.dart.js"
bash "$prepare_script" - "$temporary_path/preview-only" "$temporary_path/preview-v2.tar.gz"
test ! -e "$temporary_path/preview-only/sample-site/main.dart.js"
cmp "$preview_path/main.dart.js" "$temporary_path/preview-only/sample-site/staging/main.dart.js"

# A legacy root may coexist with a preview below a newly named root.
mkdir "$temporary_path/legacy"
cp -a "$fixture_path" "$temporary_path/legacy/old-site"
printf '<base href="/old-site/">\n' > "$temporary_path/legacy/old-site/index.html"
tar --create --gzip --directory "$temporary_path/legacy" --file "$temporary_path/legacy.tar.gz" old-site
bash "$prepare_script" "$temporary_path/legacy.tar.gz" "$temporary_path/migration" "$temporary_path/preview-v2.tar.gz"
test -s "$temporary_path/migration/old-site/main.dart.js"
test -s "$temporary_path/migration/sample-site/staging/main.dart.js"

# Validate both archives before creating output; never replace primary content.
expect_failure "$temporary_path/valid.tar.gz" "$temporary_path/valid.tar.gz"
expect_failure "$temporary_path/valid.tar.gz" "$temporary_path/corrupt.tar.gz"
printf '<base href="/sample-site/">\n' > "$preview_path/index.html"
tar --create --gzip --directory "$temporary_path/preview" --file "$temporary_path/preview-base.tar.gz" sample-site
expect_failure "$temporary_path/valid.tar.gz" "$temporary_path/preview-base.tar.gz"
printf '<base href="/sample-site/staging/">\n' > "$preview_path/index.html"
mkdir "$fixture_path/staging"
printf 'primary-owned content\n' > "$fixture_path/staging/keep.txt"
tar --create --gzip --directory "$temporary_path/fixture" --file "$temporary_path/overlap.tar.gz" sample-site
expect_failure "$temporary_path/overlap.tar.gz" "$temporary_path/preview-v2.tar.gz"

echo 'Pages tests passed: primary, preview, legacy transition, and homepage preservation.'
