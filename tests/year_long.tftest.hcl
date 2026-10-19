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

run "keeps_the_files_in_browsers_for_a_year" {
  command = plan

  assert {
    condition     = one(bunnynet_pullzone_edgerule.year_long_in_browsers.actions).type == "OverrideBrowserCacheTime" && one(bunnynet_pullzone_edgerule.year_long_in_browsers.actions).parameter1 == "31536000"
    error_message = "The browser rule must keep the files in browsers for a year, and do nothing else."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.year_long_in_browsers.enabled && bunnynet_pullzone_edgerule.year_long_in_browsers.match_type == "MatchAny" && bunnynet_pullzone_edgerule.year_long_in_browsers.pullzone == bunnynet_pullzone.site.id
    error_message = "The browser rule must be enabled on the module's pull zone, and match any of its triggers."
  }
}

run "keeps_the_files_at_the_edge_for_a_year" {
  command = plan

  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.year_long_at_the_edge : one(rule.actions).type == "OverrideCacheTime" && one(rule.actions).parameter1 == "31536000"])
    error_message = "Every edge rule must keep its files at the edge for a year, and do nothing else."
  }

  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.year_long_at_the_edge : rule.enabled && rule.pullzone == bunnynet_pullzone.site.id])
    error_message = "Every edge rule must be enabled on the module's pull zone."
  }
}

# Otherwise, a 404 kept at the edge for a year would outlive the upload that
# fixes it.
run "keeps_only_successful_responses_at_the_edge" {
  command = plan

  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.year_long_at_the_edge : rule.match_type == "MatchAll"])
    error_message = "Every edge rule must match only when all of its triggers do."
  }

  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.year_long_at_the_edge : one([for trigger in rule.triggers : trigger.patterns if trigger.type == "StatusCode"]) == tolist(["200"])])
    error_message = "Every edge rule must match only 200 responses."
  }

  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.year_long_at_the_edge : one([for trigger in rule.triggers : trigger.match_type if trigger.type == "StatusCode"]) == "MatchAny"])
    error_message = "Every edge rule's status code trigger must match a 200, not every other status."
  }

  # With `MatchAll`, a second URL trigger would narrow the rule, not widen it.
  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.year_long_at_the_edge : length(rule.triggers) == 2 && length([for trigger in rule.triggers : trigger if trigger.type == "Url"]) == 1])
    error_message = "Every edge rule must have one URL trigger and one status code trigger."
  }
}

# With a status code trigger, bunny.net would send `max-age=0` with the `304`
# that answers a browser's revalidation.
run "keeps_the_browsers_year_whatever_the_status" {
  command = plan

  assert {
    condition     = alltrue([for trigger in bunnynet_pullzone_edgerule.year_long_in_browsers.triggers : trigger.type == "Url"])
    error_message = "The browser rule must match on the URL alone."
  }
}

run "matches_the_extensions_on_the_domain" {
  command = plan

  assert {
    condition     = tolist(flatten([for trigger in bunnynet_pullzone_edgerule.year_long_in_browsers.triggers : trigger.patterns])) == tolist(["https://example.com/*.avif", "https://example.com/*.css", "https://example.com/*.gif", "https://example.com/*.jpeg", "https://example.com/*.jpg", "https://example.com/*.js", "https://example.com/*.mjs", "https://example.com/*.mp3", "https://example.com/*.mp4", "https://example.com/*.otf", "https://example.com/*.pdf", "https://example.com/*.png", "https://example.com/*.svg", "https://example.com/*.ttf", "https://example.com/*.wasm", "https://example.com/*.webm", "https://example.com/*.webp", "https://example.com/*.woff", "https://example.com/*.woff2"])
    error_message = "The browser rule must match the year-long extensions on the domain, over HTTPS."
  }

  # Each URL is in exactly one edge rule, so no two of them match the same URL.
  assert {
    condition     = tolist(flatten([for rule in bunnynet_pullzone_edgerule.year_long_at_the_edge : [for trigger in rule.triggers : trigger.patterns if trigger.type == "Url"]])) == tolist(flatten([for trigger in bunnynet_pullzone_edgerule.year_long_in_browsers.triggers : trigger.patterns]))
    error_message = "The edge rules must match the same URLs as the browser rule, each in only one rule."
  }

  assert {
    condition     = alltrue(concat([for trigger in bunnynet_pullzone_edgerule.year_long_in_browsers.triggers : trigger.match_type == "MatchAny"], flatten([for rule in bunnynet_pullzone_edgerule.year_long_at_the_edge : [for trigger in rule.triggers : trigger.match_type == "MatchAny" if trigger.type == "Url"]])))
    error_message = "Every rule must match any of its URL patterns."
  }
}

# The provider doesn't check bunny.net's limits, and what bunny.net does with a
# sixth pattern or trigger is undocumented.
run "stays_within_bunny_nets_limits" {
  command = plan

  assert {
    condition     = alltrue([for trigger in concat(bunnynet_pullzone_edgerule.year_long_in_browsers.triggers, flatten([for rule in bunnynet_pullzone_edgerule.year_long_at_the_edge : rule.triggers])) : length(trigger.patterns) <= 5])
    error_message = "Every trigger must have at most five patterns."
  }

  assert {
    condition     = length(bunnynet_pullzone_edgerule.year_long_in_browsers.triggers) <= 5
    error_message = "The browser rule must have at most five triggers."
  }
}

# Requests for the other hostname are redirected, so the rules match only the
# preferred one.
run "matches_only_the_preferred_hostname" {
  command = plan

  variables {
    prefer_www = true
  }

  assert {
    condition     = alltrue([for pattern in flatten([for trigger in bunnynet_pullzone_edgerule.year_long_in_browsers.triggers : trigger.patterns]) : startswith(pattern, "https://www.example.com/*.")])
    error_message = "With `prefer_www`, the browser rule must match `www.` and the domain."
  }

  assert {
    condition     = tolist(flatten([for rule in bunnynet_pullzone_edgerule.year_long_at_the_edge : [for trigger in rule.triggers : trigger.patterns if trigger.type == "Url"]])) == tolist(flatten([for trigger in bunnynet_pullzone_edgerule.year_long_in_browsers.triggers : trigger.patterns]))
    error_message = "The edge rules must match the same URLs as the browser rule."
  }
}
