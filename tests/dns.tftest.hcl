mock_provider "bunnynet" {
  mock_data "bunnynet_dns_zone" {
    defaults = {
      id = 3
    }
  }

  mock_resource "bunnynet_pullzone" {
    defaults = {
      id = 2
    }
  }

  mock_resource "bunnynet_storage_zone" {
    defaults = {
      id = 1
    }
  }
}

variables {
  domain     = "example.com"
  prefer_www = false
  zone_name  = "example-site"
}

# Most websites leave `dns_zone` unset. On a subdomain, that means the
# subdomain's own zone, not its parent domain's.
run "defaults_the_dns_zone_to_the_domain" {
  command = plan

  variables {
    domain = "blog.example.com"
  }

  assert {
    condition     = data.bunnynet_dns_zone.site.domain == "blog.example.com"
    error_message = "Without `dns_zone`, the module must look up the domain's own DNS zone."
  }

  assert {
    condition     = bunnynet_dns_record.bare.name == "" && bunnynet_dns_record.www.name == "www"
    error_message = "Without `dns_zone`, the records must be the zone's own domain and `www`."
  }
}

# A caller might pass on an optional variable of their own, which can be null.
run "treats_a_null_dns_zone_as_the_domain" {
  command = plan

  variables {
    dns_zone = null
  }

  assert {
    condition     = data.bunnynet_dns_zone.site.domain == "example.com"
    error_message = "A null `dns_zone` must mean the domain's own DNS zone."
  }
}

# A subdomain, so the lookup must use `dns_zone` rather than `domain`.
run "looks_up_the_dns_zone" {
  command = plan

  variables {
    dns_zone = "example.com"
    domain   = "blog.example.com"
  }

  assert {
    condition     = data.bunnynet_dns_zone.site.domain == "example.com"
    error_message = "The module must look up the DNS zone named by `dns_zone`."
  }
}

run "adds_records_for_the_zones_own_domain" {
  command = plan

  variables {
    dns_zone = "example.com"
  }

  assert {
    condition     = bunnynet_dns_record.bare.name == "" && bunnynet_dns_record.www.name == "www"
    error_message = "For the zone's own domain, the records must be the zone's own domain and `www`."
  }
}

run "adds_records_for_a_subdomain" {
  command = plan

  variables {
    dns_zone = "example.com"
    domain   = "blog.example.com"
  }

  assert {
    condition     = bunnynet_dns_record.bare.name == "blog" && bunnynet_dns_record.www.name == "www.blog"
    error_message = "For a subdomain, the records must be named relative to the zone."
  }
}

run "points_both_records_at_the_pull_zone" {
  command = plan

  assert {
    condition     = bunnynet_dns_record.bare.type == "CNAME" && bunnynet_dns_record.www.type == "CNAME"
    error_message = "Both records must be CNAME records."
  }

  assert {
    condition     = bunnynet_dns_record.bare.value == "example-site.b-cdn.net" && bunnynet_dns_record.www.value == "example-site.b-cdn.net"
    error_message = "Both records must point at `<zone_name>.b-cdn.net`."
  }

  assert {
    condition     = bunnynet_dns_record.bare.zone == data.bunnynet_dns_zone.site.id && bunnynet_dns_record.www.zone == data.bunnynet_dns_zone.site.id
    error_message = "Both records must be in the DNS zone."
  }
}

run "rejects_a_domain_outside_the_dns_zone" {
  command = plan

  expect_failures = [data.bunnynet_dns_zone.site]

  variables {
    dns_zone = "example.com"
    domain   = "example.org"
  }
}

# `notexample.com` ends with `example.com`, but isn't in the zone.
run "rejects_a_domain_that_only_ends_like_the_dns_zone" {
  command = plan

  expect_failures = [data.bunnynet_dns_zone.site]

  variables {
    dns_zone = "example.com"
    domain   = "notexample.com"
  }
}

# An empty zone isn't the same as no zone.
run "rejects_an_empty_dns_zone" {
  command = plan

  expect_failures = [var.dns_zone]

  variables {
    dns_zone = ""
  }
}

run "rejects_an_uppercase_dns_zone" {
  command = plan

  expect_failures = [var.dns_zone]

  variables {
    dns_zone = "Example.com"
  }
}

run "rejects_a_dns_zone_with_a_trailing_dot" {
  command = plan

  expect_failures = [var.dns_zone]

  variables {
    dns_zone = "example.com."
  }
}
