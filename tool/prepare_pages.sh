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
bundle_path=
bundle_name=

if [[ "$archive_path" != - ]]; then
  tar --list --gzip --file "$archive_path" > "$temporary_path/entries"
  tar --list --verbose --gzip --file "$archive_path" > "$temporary_path/types"
  if grep -Eq '(^/|(^|/)\.\.(/|$))' "$temporary_path/entries" || \
    grep -Eq '^[^d-]' "$temporary_path/types"; then
    echo 'The Web archive must contain only regular files/directories at relative paths.' >&2
    exit 1
  fi

  mkdir "$temporary_path/extracted"
  tar --extract --gzip --file "$archive_path" \
    --directory "$temporary_path/extracted" --no-same-owner --no-same-permissions
  shopt -s nullglob dotglob
  bundle_entries=("$temporary_path/extracted/"*)
  if [[ ${#bundle_entries[@]} != 1 || ! -d "${bundle_entries[0]}" ]]; then
    echo 'The archive must contain exactly one site directory.' >&2
    exit 1
  fi
  bundle_path=${bundle_entries[0]}
  bundle_name=${bundle_path##*/}
  if [[ ! "$bundle_name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || \
    [[ -n "$(git -C "$repository_path" ls-tree --name-only HEAD -- "$bundle_name")" ]]; then
    echo 'The bundle directory must be a safe, unused site subpath.' >&2
    exit 1
  fi
  for file in index.html main.dart.js flutter.js flutter_bootstrap.js \
    manifest.json assets/AssetManifest.bin assets/FontManifest.json \
    canvaskit/canvaskit.js canvaskit/canvaskit.wasm; do
    if [[ ! -s "$bundle_path/$file" ]]; then
      echo "Incomplete Web archive: missing $file." >&2
      exit 1
    fi
  done
  grep -Fq "<base href=\"/$bundle_name/\">" "$bundle_path/index.html"
  if find "$bundle_path" -type f -name '*.map' -print -quit | grep -q .; then
    echo 'Source maps must not be published.' >&2
    exit 1
  fi
fi

mkdir -p "$output_path"
git -C "$repository_path" archive HEAD | \
  tar --extract --directory "$output_path" --exclude=.github --exclude=tool
if [[ "$archive_path" != - ]]; then
  mv "$bundle_path" "$output_path/$bundle_name"
fi
