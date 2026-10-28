#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 ]]; then
  echo 'Usage: bash tool/prepare_pages.sh ARCHIVE_OR_DASH NEW_OUTPUT_DIRECTORY' >&2
  exit 1
fi

archive_path=$1
output_path=$2
repository_path=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# A fresh destination prevents stale app assets or overwriting existing files.
if [[ -e "$output_path" || -L "$output_path" ]]; then
  echo 'The Pages output directory must not exist.' >&2
  exit 1
fi

temporary_path=$(mktemp -d)
trap 'rm -rf "$temporary_path"' EXIT

if [[ "$archive_path" != - ]]; then
  tar --list --gzip --file "$archive_path" > "$temporary_path/entries"
  tar --list --verbose --gzip --file "$archive_path" > "$temporary_path/types"
  if grep -Eq '(^/|(^|/)\.\.(/|$))' "$temporary_path/entries" || \
    grep -Eq '^[^d-]' "$temporary_path/types"; then
    echo 'The Web archive must contain only regular files/directories at relative paths.' >&2
    exit 1
  fi

  mkdir "$temporary_path/app"
  tar --extract --gzip --file "$archive_path" \
    --directory "$temporary_path/app" --no-same-owner --no-same-permissions
  for file in index.html main.dart.js flutter.js flutter_bootstrap.js \
    manifest.json assets/AssetManifest.bin assets/FontManifest.json \
    canvaskit/canvaskit.js canvaskit/canvaskit.wasm; do
    if [[ ! -s "$temporary_path/app/$file" ]]; then
      echo "Incomplete Web archive: missing $file." >&2
      exit 1
    fi
  done
  grep -Fq '<base href="/antivirus-flutter/">' "$temporary_path/app/index.html"
  if find "$temporary_path/app" -type f -name '*.map' -print -quit | grep -q .; then
    echo 'Source maps must not be published.' >&2
    exit 1
  fi
fi

mkdir -p "$output_path"
git -C "$repository_path" archive HEAD | \
  tar --extract --directory "$output_path" --exclude=.github --exclude=tool
if [[ -e "$output_path/antivirus-flutter" || -L "$output_path/antivirus-flutter" ]]; then
  echo 'The app subpath must not contain tracked website files.' >&2
  exit 1
fi
if [[ "$archive_path" != - ]]; then
  mv "$temporary_path/app" "$output_path/antivirus-flutter"
fi
