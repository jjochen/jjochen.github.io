# Input is the paginated, slurped release response from gh api.
def latest_tag:
  sort_by([.published_at, .id]) | last | .tag_name // "";

(add // [])
| map(select(.draft == false and .prerelease == false)) as $releases
| ($releases | map(select(.tag_name | test("^web-bundle-production-[0-9]+-[0-9]+$")))) as $primary
| {
    production: (
      if ($primary | length) > 0 then $primary | latest_tag
      else $releases | map(select(.tag_name | test("^web-bundle-[0-9]+-[0-9]+$"))) | latest_tag
      end
    ),
    staging: (
      $releases | map(select(.tag_name | test("^web-bundle-staging-[0-9]+-[0-9]+$"))) | latest_tag
    )
  }
