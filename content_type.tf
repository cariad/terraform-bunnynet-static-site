# bunny.net serves files with extensions it doesn't recognise, such as
# `.webmanifest`, as `application/octet-stream`.
locals {
  content_types = {
    webmanifest = "application/manifest+json"
  }
}

# A missing file gets the website's `/404.html` with a 404 status, so the rules
# leave 404s alone. They don't match only a 200, so that a `304` answering a
# browser's revalidation still gets the type.
#
# No other rule sets a response header. bunny.net runs only the first matching
# action of some types, and it's untested whether `SetResponseHeader` is one of
# them, so check before letting another rule set a header on the same URLs.
resource "bunnynet_pullzone_edgerule" "content_type" {
  actions = [
    {
      parameter1 = "Content-Type"
      parameter2 = each.value
      parameter3 = null
      type       = "SetResponseHeader"
    },
  ]

  description = "Serve .${each.key} files as ${each.value}"
  enabled     = true
  match_type  = "MatchAll"
  pullzone    = bunnynet_pullzone.site.id

  triggers = [
    {
      match_type = "MatchAny"
      parameter1 = null
      parameter2 = null
      patterns   = ["https://${local.preferred_hostname}/*.${each.key}"]
      type       = "Url"
    },
    {
      match_type = "MatchNone"
      parameter1 = null
      parameter2 = null
      patterns   = ["404"]
      type       = "StatusCode"
    },
  ]

  for_each = local.content_types
}
