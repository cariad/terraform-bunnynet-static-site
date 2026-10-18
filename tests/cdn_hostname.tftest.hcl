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

run "matches_the_b_cdn_net_hostname" {
  command = plan

  assert {
    condition     = one(bunnynet_pullzone_edgerule.cdn_hostname.triggers).patterns == tolist(["http://example-site.b-cdn.net/*", "https://example-site.b-cdn.net/*"])
    error_message = "The redirect must match both schemes on `<zone_name>.b-cdn.net`, and nothing else."
  }

  # MatchNone would redirect every other hostname, including the domain, to the
  # domain, in a loop.
  assert {
    condition     = one(bunnynet_pullzone_edgerule.cdn_hostname.triggers).type == "Url" && one(bunnynet_pullzone_edgerule.cdn_hostname.triggers).match_type == "MatchAny"
    error_message = "The redirect must match any of its URL patterns."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.cdn_hostname.enabled && bunnynet_pullzone_edgerule.cdn_hostname.match_type == "MatchAny" && bunnynet_pullzone_edgerule.cdn_hostname.pullzone == bunnynet_pullzone.site.id
    error_message = "The redirect must be enabled on the module's pull zone, and match any of its triggers."
  }
}

run "redirects_permanently_to_the_same_path_on_the_domain" {
  command = plan

  assert {
    condition     = one(bunnynet_pullzone_edgerule.cdn_hostname.actions).type == "Redirect"
    error_message = "The rule must redirect."
  }

  assert {
    condition     = one(bunnynet_pullzone_edgerule.cdn_hostname.actions).parameter1 == "https://example.com{{path}}"
    error_message = "The redirect must keep the path, on the domain, over HTTPS."
  }

  assert {
    condition     = one(bunnynet_pullzone_edgerule.cdn_hostname.actions).parameter2 == "301"
    error_message = "The redirect must be permanent."
  }
}

run "redirects_to_www_when_it_is_preferred" {
  command = plan

  variables {
    prefer_www = true
  }

  assert {
    condition     = one(bunnynet_pullzone_edgerule.cdn_hostname.actions).parameter1 == "https://www.example.com{{path}}"
    error_message = "With `prefer_www`, the redirect must go to `www.` and the domain."
  }
}
