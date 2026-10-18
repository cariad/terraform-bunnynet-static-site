# Unlike the other test files, this one has no `mock_provider`, so the real
# provider plans the resources and applies its own defaults. It checks what the
# mock can't: settings whose removal the mock wouldn't notice, because it would
# give them the same values, and provider defaults that the module relies on.
#
# Planning new resources makes no API calls, so this needs no API key. Assert
# only on values that come from the configuration or the provider's defaults:
# computed values, such as IDs, are unknown in a real plan.
#
# Every run must set `command = plan`. A run without it applies, which would
# create real zones on the account of anyone with `BUNNYNET_API_KEY` set.

# Points the provider at a host that can't exist, so that if a run ever applies
# by mistake, it fails without reaching bunny.net. `BUNNYNET_API_URL` would
# override this.
provider "bunnynet" {
  api_url = "https://api.invalid"
}

# Looking up the DNS zone would call bunny.net's API, even when planning.
override_data {
  target = data.bunnynet_dns_zone.site

  values = {
    id = 3
  }
}

variables {
  domain     = "example.com"
  prefer_www = false
  zone_name  = "example-site"
}

# The module leaves error caching at the provider's default. If the edge kept a
# 404, a file uploaded afterwards would stay missing until the 404 expired.
run "does_not_keep_errors" {
  command = plan

  assert {
    condition     = !bunnynet_pullzone.site.cache_errors
    error_message = "The pull zone mustn't keep error responses."
  }
}

run "tells_browsers_to_check_before_reusing_files" {
  command = plan

  assert {
    condition     = bunnynet_pullzone.site.cache_expiration_time_browser == 0
    error_message = "Browsers must check with the edge before reusing a file, unless an edge rule says otherwise."
  }
}

# The module leaves the storage zone's type to the provider's default. A change
# to the default would replace every caller's storage zone, and an S3-compatible
# storage zone could replicate to only 8 regions.
run "uses_the_standard_storage_type" {
  command = plan

  assert {
    condition     = bunnynet_storage_zone.site.type == "Standard"
    error_message = "The storage zone must use the Standard type."
  }
}

# The module leaves the tier to the provider's default.
run "uses_the_standard_tier" {
  command = plan

  assert {
    condition     = bunnynet_pullzone.site.routing.tier == "Standard"
    error_message = "The pull zone must use the Standard tier."
  }
}

# CDN Acceleration would put the names on separate pull zones. Without
# `accelerated = false`, the provider would leave it unknown.
run "leaves_cdn_acceleration_off" {
  command = plan

  assert {
    condition     = !bunnynet_dns_record.bare.accelerated && !bunnynet_dns_record.www.accelerated
    error_message = "Neither record may use CDN Acceleration."
  }
}
