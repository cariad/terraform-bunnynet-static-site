variable "dns_zone" {
  default     = null
  description = "The domain of the Bunny DNS zone that holds the website's DNS records, such as `example.com`. Defaults to `domain`."
  nullable    = true
  type        = string

  validation {
    # Null means the domain, which has its own validation. OpenTofu still
    # evaluates the right of `||`, but drops its errors when the left is true.
    #
    # The regex is a copy of `domain`'s, so change both together.
    condition = var.dns_zone == null || (
      length(var.dns_zone) <= 253 &&
      can(
        regex(
          "^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$",
          var.dns_zone,
        ),
      )
    )
    error_message = "The DNS zone must be a lowercase domain such as \"example.com\", of at most 253 characters, with no scheme, port, path or trailing dot."
  }
}

variable "domain" {
  description = "The website's bare domain, such as `example.com`, without `www.`."
  nullable    = false
  type        = string

  validation {
    # The module adds `www.` itself, so the domain can't start with it, and must
    # leave room for it within a hostname's 253 characters.
    condition = (
      length(var.domain) <= 249 &&
      !startswith(var.domain, "www.") &&
      can(
        regex(
          "^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$",
          var.domain,
        ),
      )
    )
    error_message = "The domain must be a lowercase hostname such as \"example.com\", without \"www.\" at the start, of at most 249 characters, with no scheme, port, path or trailing dot."
  }
}

variable "prefer_www" {
  description = "Whether to serve the website from `www.<domain>` and redirect `<domain>` to it, rather than the other way round."
  nullable    = false
  type        = bool
}

variable "zone_name" {
  description = "The name of the storage zone and the pull zone."
  nullable    = false
  type        = string

  validation {
    # The storage zone allows 4 to 64 of `[a-z0-9-]`, and the pull zone's name
    # becomes a DNS label, which is at most 63 characters and can't start or end
    # with a hyphen.
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,61}[a-z0-9]$", var.zone_name))
    error_message = "The zone name must be 4 to 63 lowercase letters, digits and hyphens, starting and ending with a letter or digit."
  }
}
