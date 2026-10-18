# Every pull zone also answers on `<zone_name>.b-cdn.net`, and that can't be
# turned off, so this rule directs requests to the preferred hostname.
resource "bunnynet_pullzone_edgerule" "cdn_hostname" {
  actions = [
    {
      parameter1 = "https://${local.preferred_hostname}{{path}}"
      parameter2 = "301"
      parameter3 = null
      type       = "Redirect"
    },
  ]

  description = "Redirect the b-cdn.net hostname to the preferred hostname"
  enabled     = true
  match_type  = "MatchAny"
  pullzone    = bunnynet_pullzone.site.id

  triggers = [
    {
      match_type = "MatchAny"
      parameter1 = null
      parameter2 = null
      patterns = [
        "http://${bunnynet_pullzone.site.name}.b-cdn.net/*",
        "https://${bunnynet_pullzone.site.name}.b-cdn.net/*",
      ]
      type = "Url"
    },
  ]
}
