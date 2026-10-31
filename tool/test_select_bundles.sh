#!/usr/bin/env bash
set -euo pipefail

repository_path=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
selector="$repository_path/tool/select_bundles.jq"
selection=$(printf '[[]]\n' | jq -c -f "$selector")
test "$selection" == '{"production":"","staging":""}'

selection=$(jq -c -f "$selector" <<'JSON'
[[
  {"id":1,"tag_name":"web-bundle-10-1","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"}
]]
JSON
)
test "$(jq -r .production <<< "$selection")" == web-bundle-10-1
test "$(jq -r .staging <<< "$selection")" == ''

selection=$(jq -c -f "$selector" <<'JSON'
[[
  {"id":1,"tag_name":"web-bundle-10-1","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"},
  {"id":2,"tag_name":"web-bundle-production-20-1","draft":false,"prerelease":false,"published_at":"2026-01-02T00:00:00Z"},
  {"id":4,"tag_name":"web-bundle-staging-40-1","draft":false,"prerelease":false,"published_at":"2026-01-04T00:00:00Z"},
  {"id":5,"tag_name":"web-bundle-production-50-1","draft":true,"prerelease":false,"published_at":"2026-01-05T00:00:00Z"},
  {"id":6,"tag_name":"web-bundle-staging-60-1","draft":false,"prerelease":true,"published_at":"2026-01-06T00:00:00Z"},
  {"id":9,"tag_name":"unrelated-release","draft":false,"prerelease":false,"published_at":"2026-01-09T00:00:00Z"}
], [
  {"id":3,"tag_name":"web-bundle-production-30-1","draft":false,"prerelease":false,"published_at":"2026-01-03T00:00:00Z"},
  {"id":7,"tag_name":"web-bundle-staging-70-1","draft":false,"prerelease":false,"published_at":"2026-01-07T00:00:00Z"},
  {"id":8,"tag_name":"web-bundle-80-1","draft":false,"prerelease":false,"published_at":"2026-01-08T00:00:00Z"}
]]
JSON
)
test "$(jq -r .production <<< "$selection")" == web-bundle-production-30-1
test "$(jq -r .staging <<< "$selection")" == web-bundle-staging-70-1

selection=$(jq -c -f "$selector" <<'JSON'
[[
  {"id":2,"tag_name":"web-bundle-staging-20-1","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"},
  {"id":3,"tag_name":"web-bundle-staging-30-1","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"}
]]
JSON
)
test "$(jq -r .production <<< "$selection")" == ''
test "$(jq -r .staging <<< "$selection")" == web-bundle-staging-30-1
echo 'Independent channel selection, empty releases, legacy fallback, and deterministic ordering passed.'
