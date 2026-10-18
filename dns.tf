# The website's two DNS records, in the caller's existing Bunny DNS zone. The
# zone, and any other records in it, remain the caller's to manage.

locals {
  # Most websites are on their zone's own domain, so that's the default.
  dns_zone = coalesce(var.dns_zone, var.domain)
}

data "bunnynet_dns_zone" "site" {
  domain = local.dns_zone

  lifecycle {
    precondition {
      condition     = var.domain == local.dns_zone || endswith(var.domain, ".${local.dns_zone}")
      error_message = "The domain must be in the DNS zone."
    }
  }
}

locals {
  # The records' names within the zone. The bare domain's is empty when it's the
  # zone's own domain, or the labels in front of it, such as `blog` for
  # `blog.example.com` in the `example.com` zone.
  bare_record_name = var.domain == local.dns_zone ? "" : trimsuffix(var.domain, ".${local.dns_zone}")
  www_record_name  = local.bare_record_name == "" ? "www" : "www.${local.bare_record_name}"
}

# Bunny DNS flattens a `CNAME` record on a zone's own domain into the addresses
# it points at, and bunny.net doesn't support `A` records pointing at its IP
# addresses.
#
# CDN Acceleration is off, because it would put the name on a separate pull
# zone, and a name can belong to only one pull zone.
resource "bunnynet_dns_record" "bare" {
  accelerated = false
  name        = local.bare_record_name
  type        = "CNAME"
  value       = "${bunnynet_pullzone.site.name}.b-cdn.net"
  zone        = data.bunnynet_dns_zone.site.id
}

resource "bunnynet_dns_record" "www" {
  accelerated = false
  name        = local.www_record_name
  type        = "CNAME"
  value       = "${bunnynet_pullzone.site.name}.b-cdn.net"
  zone        = data.bunnynet_dns_zone.site.id
}
