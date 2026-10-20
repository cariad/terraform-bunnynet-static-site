# Images, fonts, stylesheets, scripts, documents, audio and video are kept for a
# year at the edge and in browsers, whether or not their names are
# fingerprinted. A purge can't clear them from browsers, so a file with one of
# these extensions must be renamed whenever it changes.
#
# Every other file keeps the pull zone's five-minute cache. That includes pages,
# feeds and data (`html`, `xml`, `json` and `txt`), and `favicon.ico`, which
# browsers ask for by name.
locals {
  # bunny.net allows at most five patterns per trigger.
  year_long_extension_groups = chunklist(local.year_long_extensions, 5)

  year_long_extensions = [
    "avif",
    "css",
    "gif",
    "jpeg",
    "jpg",
    "js",
    "mjs",
    "mp3",
    "mp4",
    "otf",
    "pdf",
    "png",
    "svg",
    "ttf",
    "wasm",
    "webm",
    "webp",
    "woff",
    "woff2",
  ]

  # bunny.net's `*` matches any characters, including `/`, in the whole URL
  # without its query string. Requests for the other hostname are redirected, so
  # the rules needn't match them.
  year_long_url_patterns = [
    for group in local.year_long_extension_groups : [
      for extension in group : "https://${local.preferred_hostname}/*.${extension}"
    ]
  ]
}

# bunny.net sends a 404 with `no-cache` even when this rule matches, so browsers
# never keep a missing file.
#
# This rule matches on the URL alone. With a status code trigger, bunny.net
# would send `max-age=0` with the `304` that answers a browser's revalidation,
# and the browser would then check the file every time.
#
# It has one trigger per group of extensions, and matches any of them. bunny.net
# allows at most five triggers per rule.
resource "bunnynet_pullzone_edgerule" "year_long_in_browsers" {
  actions = [
    {
      parameter1 = "31536000" # One year in seconds
      parameter2 = null
      parameter3 = null
      type       = "OverrideBrowserCacheTime"
    },
  ]

  description = "Keep ${join(", ", local.year_long_extensions)} files in browsers for a year"
  enabled     = true
  match_type  = "MatchAny"
  pullzone    = bunnynet_pullzone.site.id

  triggers = [
    for patterns in local.year_long_url_patterns : {
      match_type = "MatchAny"
      parameter1 = null
      parameter2 = null
      patterns   = patterns
      type       = "Url"
    }
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
#
# There's one rule per group of extensions, because a rule that matches all of
# its triggers can't also match any of several URL triggers. The groups don't
# overlap, so no two of these rules match the same URL.
resource "bunnynet_pullzone_edgerule" "year_long_at_the_edge" {
  actions = [
    {
      parameter1 = "31536000" # One year in seconds
      parameter2 = null
      parameter3 = null
      type       = "OverrideCacheTime"
    },
  ]

  description = "Keep ${join(", ", local.year_long_extension_groups[count.index])} files at the edge for a year"
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
      patterns   = local.year_long_url_patterns[count.index]
      type       = "Url"
    },
  ]

  count = length(local.year_long_extension_groups)
}
