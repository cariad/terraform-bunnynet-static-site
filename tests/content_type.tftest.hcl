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

run "serves_web_manifests_as_manifest_json" {
  command = plan

  assert {
    condition     = one(bunnynet_pullzone_edgerule.content_type["webmanifest"].actions).type == "SetResponseHeader" && one(bunnynet_pullzone_edgerule.content_type["webmanifest"].actions).parameter1 == "Content-Type" && one(bunnynet_pullzone_edgerule.content_type["webmanifest"].actions).parameter2 == "application/manifest+json"
    error_message = "The rule must set the `Content-Type` header to `application/manifest+json`, and do nothing else."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.content_type["webmanifest"].enabled && bunnynet_pullzone_edgerule.content_type["webmanifest"].pullzone == bunnynet_pullzone.site.id
    error_message = "The rule must be enabled on the module's pull zone."
  }
}

run "matches_web_manifests_on_the_domain" {
  command = plan

  assert {
    condition     = one([for trigger in bunnynet_pullzone_edgerule.content_type["webmanifest"].triggers : trigger.patterns if trigger.type == "Url"]) == tolist(["https://example.com/*.webmanifest"])
    error_message = "The rule must match `.webmanifest` files on the domain, over HTTPS."
  }

  # `MatchNone` would set the type on every other file, including pages.
  assert {
    condition     = one([for trigger in bunnynet_pullzone_edgerule.content_type["webmanifest"].triggers : trigger.match_type if trigger.type == "Url"]) == "MatchAny"
    error_message = "The rule's URL trigger must match any of its patterns."
  }
}

# Otherwise, a missing manifest's `/404.html` would be served as a manifest.
run "leaves_404s_alone" {
  command = plan

  # `MatchAny` would set the type on every response that isn't a 404, including
  # pages.
  assert {
    condition     = bunnynet_pullzone_edgerule.content_type["webmanifest"].match_type == "MatchAll"
    error_message = "The rule must match only when all of its triggers do."
  }

  assert {
    condition     = one([for trigger in bunnynet_pullzone_edgerule.content_type["webmanifest"].triggers : trigger.patterns if trigger.type == "StatusCode"]) == tolist(["404"]) && one([for trigger in bunnynet_pullzone_edgerule.content_type["webmanifest"].triggers : trigger.match_type if trigger.type == "StatusCode"]) == "MatchNone"
    error_message = "The rule's status code trigger must match every status except a 404."
  }

  assert {
    condition     = length(bunnynet_pullzone_edgerule.content_type["webmanifest"].triggers) == 2
    error_message = "The rule must have one URL trigger and one status code trigger."
  }
}

# Requests for the other hostname are redirected, so the rule matches only the
# preferred one.
run "matches_only_the_preferred_hostname" {
  command = plan

  variables {
    prefer_www = true
  }

  assert {
    condition     = one([for trigger in bunnynet_pullzone_edgerule.content_type["webmanifest"].triggers : trigger.patterns if trigger.type == "Url"]) == tolist(["https://www.example.com/*.webmanifest"])
    error_message = "With `prefer_www`, the rule must match `.webmanifest` files on `www.` and the domain."
  }
}
