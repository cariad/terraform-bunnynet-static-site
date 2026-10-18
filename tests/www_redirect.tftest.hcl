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

run "redirects_www_to_the_bare_domain" {
  command = plan

  assert {
    condition     = one(bunnynet_pullzone_edgerule.www_redirect.actions).parameter1 == "https://example.com{{path}}"
    error_message = "Without `prefer_www`, the redirect must keep the path, on the domain, over HTTPS."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.www_redirect.triggers[0].patterns == tolist(["http://www.example.com/*", "https://www.example.com/*"])
    error_message = "Without `prefer_www`, the redirect must match both schemes on `www.` and the domain."
  }
}

run "redirects_the_bare_domain_to_www" {
  command = plan

  variables {
    prefer_www = true
  }

  assert {
    condition     = one(bunnynet_pullzone_edgerule.www_redirect.actions).parameter1 == "https://www.example.com{{path}}"
    error_message = "With `prefer_www`, the redirect must keep the path, on `www.` and the domain, over HTTPS."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.www_redirect.triggers[0].patterns == tolist(["http://example.com/*", "https://example.com/*"])
    error_message = "With `prefer_www`, the redirect must match both schemes on the domain."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.www_redirect.triggers[1].patterns == tolist(["http://example.com/.well-known/acme-challenge/*", "https://example.com/.well-known/acme-challenge/*"])
    error_message = "With `prefer_www`, the second trigger must cover Let's Encrypt challenges on the domain."
  }
}

run "redirects_permanently" {
  command = plan

  assert {
    condition     = one(bunnynet_pullzone_edgerule.www_redirect.actions).type == "Redirect" && one(bunnynet_pullzone_edgerule.www_redirect.actions).parameter2 == "301"
    error_message = "The rule must redirect permanently."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.www_redirect.enabled && bunnynet_pullzone_edgerule.www_redirect.pullzone == bunnynet_pullzone.site.id
    error_message = "The rule must be enabled on the module's pull zone."
  }
}

# MatchAny would redirect every request that isn't a Let's Encrypt challenge,
# including those for the preferred hostname, in a loop.
run "leaves_lets_encrypt_challenges_alone" {
  command = plan

  assert {
    condition     = bunnynet_pullzone_edgerule.www_redirect.match_type == "MatchAll"
    error_message = "The rule must need both triggers to match."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.www_redirect.triggers[0].type == "Url" && bunnynet_pullzone_edgerule.www_redirect.triggers[0].match_type == "MatchAny"
    error_message = "The first trigger must match any of the redirected hostname's URL patterns."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.www_redirect.triggers[1].type == "Url" && bunnynet_pullzone_edgerule.www_redirect.triggers[1].match_type == "MatchNone"
    error_message = "The second trigger must match only URLs that aren't Let's Encrypt challenges."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.www_redirect.triggers[1].patterns == tolist(["http://www.example.com/.well-known/acme-challenge/*", "https://www.example.com/.well-known/acme-challenge/*"])
    error_message = "The second trigger must cover Let's Encrypt challenges on the redirected hostname."
  }
}
