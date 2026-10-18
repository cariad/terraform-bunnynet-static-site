# Sends whichever of `<domain>` and `www.<domain>` isn't preferred to the one
# that is, keeping the path and query string.
resource "bunnynet_pullzone_edgerule" "www_redirect" {
  actions = [
    {
      parameter1 = "https://${local.preferred_hostname}{{path}}"
      parameter2 = "301"
      parameter3 = null
      type       = "Redirect"
    },
  ]

  description = "Redirect to the preferred hostname"
  enabled     = true

  # Don't redirect Let's Encrypt challenges.
  match_type = "MatchAll"
  pullzone   = bunnynet_pullzone.site.id

  triggers = [
    {
      match_type = "MatchAny"
      parameter1 = null
      parameter2 = null
      patterns = [
        "http://${local.redirected_hostname}/*",
        "https://${local.redirected_hostname}/*",
      ]
      type = "Url"
    },
    {
      match_type = "MatchNone"
      parameter1 = null
      parameter2 = null
      patterns = [
        "http://${local.redirected_hostname}/.well-known/acme-challenge/*",
        "https://${local.redirected_hostname}/.well-known/acme-challenge/*",
      ]
      type = "Url"
    },
  ]
}
