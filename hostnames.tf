# The website answers on both `<domain>` and `www.<domain>`, because visitors
# type and link `www.` out of habit, and Chrome turns `example` into
# `www.example.com` when you press Ctrl+Enter. One is preferred, and
# `www_redirect.tf` sends the other to it.
#
# The resources are named after their hostnames rather than their roles, so
# that changing `prefer_www` updates them in place rather than replacing them.
locals {
  # These refer to the hostnames' resources rather than `var.domain`, to force
  # OpenTofu to create the edge rules that use them *after* both hostnames, and
  # so after both certificates.
  preferred_hostname  = var.prefer_www ? bunnynet_pullzone_hostname.www.name : bunnynet_pullzone_hostname.bare.name
  redirected_hostname = var.prefer_www ? bunnynet_pullzone_hostname.bare.name : bunnynet_pullzone_hostname.www.name
}

# The provider adds each hostname then asks bunny.net for its free certificate,
# so the domain's DNS *must* already point at bunny.net. `depends_on` makes
# OpenTofu create each hostname after its DNS record in `dns.tf`.
#
# Only the preferred hostname forces HTTPS. `www_redirect.tf` sends HTTP
# requests for the other one straight to HTTPS on the preferred hostname, in one
# hop rather than two.
resource "bunnynet_pullzone_hostname" "bare" {
  force_ssl   = !var.prefer_www
  name        = var.domain
  pullzone    = bunnynet_pullzone.site.id
  tls_enabled = true

  depends_on = [bunnynet_dns_record.bare]
}

resource "bunnynet_pullzone_hostname" "www" {
  force_ssl   = var.prefer_www
  name        = "www.${var.domain}"
  pullzone    = bunnynet_pullzone.site.id
  tls_enabled = true

  depends_on = [bunnynet_dns_record.www]
}
