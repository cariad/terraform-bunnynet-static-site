# Files named `*.<hash>.*`, where the hash is 64 lowercase hexadecimal
# characters (like Hugo's default SHA-256 fingerprint), are kept for a year at
# the edge and in browsers.
#
# Their names change whenever their contents do, so a year is safe.
#
# Every other file keeps the pull zone's five-minute cache, so a file that isn't
# fingerprinted is never stuck for long.
locals {
  # The `pattern:` prefix makes bunny.net match the URL, without its query
  # string, with Lua's `string.find` rather than `*` wildcards.
  fingerprinted_url_pattern = "pattern:^https://${local.hostname_pattern}/.*%.${local.sha256_pattern}%.[^./]+$"

  # The preferred hostname as a Lua pattern. Requests for the other hostname are
  # redirected, so the rules needn't match them.
  #
  # `.` and `-` are the only special characters that we allow, and `%` escapes
  # them.
  hostname_pattern = replace(
    replace(
      local.preferred_hostname,
      "-",
      "%-",
    ),
    ".",
    "%.",
  )

  # Lua patterns have no `{64}`, so the class is written out 64 times.
  sha256_pattern = join("", [for i in range(64) : "[0-9a-f]"])
}

# bunny.net sends a 404 with `no-cache` even when this rule matches, so browsers
# never keep a missing file.
#
# This rule matches on the URL alone. With a status code trigger, bunny.net
# would send `max-age=0` with the `304` that answers a browser's revalidation,
# and the browser would then check the file every time.
resource "bunnynet_pullzone_edgerule" "year_long_in_browsers" {
  actions = [
    {
      parameter1 = "31536000" # One year in seconds
      parameter2 = null
      parameter3 = null
      type       = "OverrideBrowserCacheTime"
    },
  ]

  description = "Keep fingerprinted files in browsers for a year"
  enabled     = true
  match_type  = "MatchAny"
  pullzone    = bunnynet_pullzone.site.id

  triggers = [
    {
      match_type = "MatchAny"
      parameter1 = null
      parameter2 = null
      patterns   = [local.fingerprinted_url_pattern]
      type       = "Url"
    },
  ]
}

# Without the status code trigger, the edge could keep a 404 for up to a year,
# and serve it to every visitor who reaches it, even after the file is uploaded.
# That could happen to a visitor who asks for a file before it's uploaded.
#
# bunny.net doesn't document when it checks a status code trigger, but another
# bunny.net site with this gate kept its files at the edge and never kept a 404.
#
# If bunny.net ever fetches a file with another status, such as a `304` for a
# browser's revalidation or a `206` for a range, that edge location keeps the
# file for the pull zone's five minutes instead. That costs only extra fetches
# from storage.
resource "bunnynet_pullzone_edgerule" "year_long_at_the_edge" {
  actions = [
    {
      parameter1 = "31536000" # One year in seconds
      parameter2 = null
      parameter3 = null
      type       = "OverrideCacheTime"
    },
  ]

  description = "Keep fingerprinted files at the edge for a year"
  enabled     = true
  match_type  = "MatchAll"
  pullzone    = bunnynet_pullzone.site.id

  triggers = [
    {
      match_type = "MatchAny"
      parameter1 = null
      parameter2 = null
      patterns   = ["200"]
      type       = "StatusCode"
    },
    {
      match_type = "MatchAny"
      parameter1 = null
      parameter2 = null
      patterns   = [local.fingerprinted_url_pattern]
      type       = "Url"
    },
  ]
}
