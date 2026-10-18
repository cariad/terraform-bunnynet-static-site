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

run "keeps_fingerprinted_files_in_browsers_for_a_year" {
  command = plan

  assert {
    condition     = one(bunnynet_pullzone_edgerule.year_long_in_browsers.actions).type == "OverrideBrowserCacheTime" && one(bunnynet_pullzone_edgerule.year_long_in_browsers.actions).parameter1 == "31536000"
    error_message = "The browser rule must keep fingerprinted files in browsers for a year, and do nothing else."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.year_long_in_browsers.enabled && bunnynet_pullzone_edgerule.year_long_in_browsers.match_type == "MatchAny" && bunnynet_pullzone_edgerule.year_long_in_browsers.pullzone == bunnynet_pullzone.site.id
    error_message = "The browser rule must be enabled on the module's pull zone, and match any of its triggers."
  }
}

run "keeps_fingerprinted_files_at_the_edge_for_a_year" {
  command = plan

  assert {
    condition     = one(bunnynet_pullzone_edgerule.year_long_at_the_edge.actions).type == "OverrideCacheTime" && one(bunnynet_pullzone_edgerule.year_long_at_the_edge.actions).parameter1 == "31536000"
    error_message = "The edge rule must keep fingerprinted files at the edge for a year, and do nothing else."
  }

  assert {
    condition     = bunnynet_pullzone_edgerule.year_long_at_the_edge.enabled && bunnynet_pullzone_edgerule.year_long_at_the_edge.pullzone == bunnynet_pullzone.site.id
    error_message = "The edge rule must be enabled on the module's pull zone."
  }
}

# Otherwise, a 404 kept at the edge for a year would outlive the upload that
# fixes it.
run "keeps_only_successful_responses_at_the_edge" {
  command = plan

  assert {
    condition     = bunnynet_pullzone_edgerule.year_long_at_the_edge.match_type == "MatchAll"
    error_message = "The edge rule must match only when all of its triggers do."
  }

  assert {
    condition     = one([for trigger in bunnynet_pullzone_edgerule.year_long_at_the_edge.triggers : trigger.patterns if trigger.type == "StatusCode"]) == tolist(["200"])
    error_message = "The edge rule must match only 200 responses."
  }

  assert {
    condition     = one([for trigger in bunnynet_pullzone_edgerule.year_long_at_the_edge.triggers : trigger.match_type if trigger.type == "StatusCode"]) == "MatchAny"
    error_message = "The edge rule's status code trigger must match a 200, not every other status."
  }
}

# With a status code trigger, bunny.net would send `max-age=0` with the `304`
# that answers a browser's revalidation.
run "keeps_the_browsers_year_whatever_the_status" {
  command = plan

  assert {
    condition     = one(bunnynet_pullzone_edgerule.year_long_in_browsers.triggers).type == "Url"
    error_message = "The browser rule must match on the URL alone."
  }
}

# The `[0-9a-f]` class is written out 64 times, because Lua patterns have no
# `{64}`.
run "matches_names_with_a_sha_256_hash_on_the_domain" {
  command = plan

  assert {
    condition     = one(bunnynet_pullzone_edgerule.year_long_in_browsers.triggers).patterns == tolist(["pattern:^https://example%.com/.*%.[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]%.[^./]+$"])
    error_message = "The browser rule must match `<name>.<64 lowercase hex characters>.<extension>` on the domain, over HTTPS."
  }

  assert {
    condition     = one([for trigger in bunnynet_pullzone_edgerule.year_long_at_the_edge.triggers : trigger.patterns if trigger.type == "Url"]) == one(bunnynet_pullzone_edgerule.year_long_in_browsers.triggers).patterns
    error_message = "The edge rule must match the same URLs as the browser rule."
  }

  assert {
    condition     = one(bunnynet_pullzone_edgerule.year_long_in_browsers.triggers).match_type == "MatchAny" && one([for trigger in bunnynet_pullzone_edgerule.year_long_at_the_edge.triggers : trigger.match_type if trigger.type == "Url"]) == "MatchAny"
    error_message = "Both rules must match any of their URL patterns."
  }
}

# In a Lua pattern, `-` is a repeater, so the domain's hyphens must be escaped
# as well as its dots.
run "escapes_the_domain_for_lua" {
  command = plan

  variables {
    domain = "my-site.example.com"
  }

  assert {
    condition     = startswith(one(one(bunnynet_pullzone_edgerule.year_long_in_browsers.triggers).patterns), "pattern:^https://my%-site%.example%.com/.*%.")
    error_message = "The rules must escape the domain's hyphens and dots."
  }

  assert {
    condition     = one([for trigger in bunnynet_pullzone_edgerule.year_long_at_the_edge.triggers : trigger.patterns if trigger.type == "Url"]) == one(bunnynet_pullzone_edgerule.year_long_in_browsers.triggers).patterns
    error_message = "The edge rule must match the same URLs as the browser rule."
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
    condition     = startswith(one(one(bunnynet_pullzone_edgerule.year_long_in_browsers.triggers).patterns), "pattern:^https://www%.example%.com/.*%.")
    error_message = "With `prefer_www`, the rules must match `www.` and the domain."
  }

  assert {
    condition     = one([for trigger in bunnynet_pullzone_edgerule.year_long_at_the_edge.triggers : trigger.patterns if trigger.type == "Url"]) == one(bunnynet_pullzone_edgerule.year_long_in_browsers.triggers).patterns
    error_message = "The edge rule must match the same URLs as the browser rule."
  }
}
