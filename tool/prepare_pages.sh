#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 && $# != 3 ]]; then
  echo 'Usage: bash tool/prepare_pages.sh PRIMARY_ARCHIVE_OR_DASH NEW_OUTPUT_DIRECTORY [PREVIEW_ARCHIVE_OR_DASH]' >&2
  exit 1
fi

archive_paths=("$1" "${3:--}")
output_path=$2
repository_path=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# A fresh destination prevents stale app assets or overwriting existing files.
if [[ -e "$output_path" || -L "$output_path" ]]; then
  echo 'The Pages output directory must not exist.' >&2
  exit 1
fi

temporary_path=$(mktemp -d)
trap 'rm -rf "$temporary_path"' EXIT
bundle_paths=()
bundle_names=()
shopt -s nullglob dotglob

for index in 0 1; do
  archive_path=${archive_paths[$index]}
  if [[ "$archive_path" == - ]]; then continue; fi
  archive_work="$temporary_path/$index"
  mkdir "$archive_work"
  tar --list --gzip --file "$archive_path" > "$archive_work/entries"
  tar --list --verbose --gzip --file "$archive_path" > "$archive_work/types"
  if grep -Eq '(^/|(^|/)\.\.(/|$))' "$archive_work/entries" || \
    grep -Eq '^[^d-]' "$archive_work/types"; then
    echo 'The Web archive must contain only regular files/directories at relative paths.' >&2
    exit 1
  fi

  mkdir "$archive_work/extracted"
  tar --extract --gzip --file "$archive_path" \
    --directory "$archive_work/extracted" --no-same-owner --no-same-permissions
  bundle_entries=("$archive_work/extracted/"*)
  if [[ ${#bundle_entries[@]} != 1 || ! -d "${bundle_entries[0]}" ]]; then
    echo 'The archive must contain exactly one site directory.' >&2
    exit 1
  fi
  bundle_path=${bundle_entries[0]}
  bundle_name=${bundle_path##*/}
  if [[ "$index" == 1 ]]; then
    # A preview has one directory below its site root; ancestors contain no files.
    nested_entries=("$bundle_path/"*)
    if [[ ${#nested_entries[@]} != 1 || ! -d "${nested_entries[0]}" ]]; then
      echo 'The preview archive must contain exactly one nested site directory.' >&2
      exit 1
    fi
    bundle_path=${nested_entries[0]}
    bundle_name="$bundle_name/${bundle_path##*/}"
  fi
  site_root=${bundle_name%%/*}
  if [[ ! "$bundle_name" =~ ^[a-z0-9][a-z0-9-]*(/[a-z0-9][a-z0-9-]*)?$ ]] || \
    [[ -n "$(git -C "$repository_path" ls-tree --name-only HEAD -- "$site_root")" ]]; then
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
  for previous in "${!bundle_names[@]}"; do
    previous_name=${bundle_names[$previous]}
    if [[ "$bundle_name" == "$previous_name" || \
      ( "$bundle_name" == "$previous_name/"* && \
        ( -e "${bundle_paths[$previous]}/${bundle_name#"$previous_name/"}" || \
          -L "${bundle_paths[$previous]}/${bundle_name#"$previous_name/"}" ) ) ]]; then
      echo 'The preview must not replace content from the primary bundle.' >&2
      exit 1
    fi
  done
  bundle_paths+=("$bundle_path")
  bundle_names+=("$bundle_name")
done

# Both archives are validated before creating any output.
mkdir -p "$output_path"
git -C "$repository_path" archive HEAD | \
  tar --extract --directory "$output_path" --exclude=.github --exclude=tool
for index in "${!bundle_paths[@]}"; do
  destination="$output_path/${bundle_names[$index]}"
  if [[ -e "$destination" || -L "$destination" ]]; then
    echo 'A bundle must not replace an existing destination.' >&2
    exit 1
  fi
  mkdir -p "$(dirname "$destination")"
  mv "${bundle_paths[$index]}" "$destination"
done
