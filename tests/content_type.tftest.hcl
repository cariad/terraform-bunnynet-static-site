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

# bunny.net serves these extensions as `application/octet-stream`, and browsers
# refuse to run a JavaScript module served that way.
run "serves_each_extension_with_its_type" {
  command = plan

  assert {
    condition     = { for extension, rule in bunnynet_pullzone_edgerule.content_type : extension => one(rule.actions).parameter2 } == { mjs = "text/javascript", otf = "font/otf", ttf = "font/ttf", webmanifest = "application/manifest+json" }
    error_message = "There must be one rule for each of `.mjs`, `.otf`, `.ttf` and `.webmanifest`, serving them as `text/javascript`, `font/otf`, `font/ttf` and `application/manifest+json`."
  }

  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.content_type : one(rule.actions).type == "SetResponseHeader" && one(rule.actions).parameter1 == "Content-Type"])
    error_message = "Every rule must set the `Content-Type` header, and do nothing else."
  }

  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.content_type : rule.enabled && rule.pullzone == bunnynet_pullzone.site.id])
    error_message = "Every rule must be enabled on the module's pull zone."
  }
}

run "matches_each_extension_on_the_domain" {
  command = plan

  assert {
    condition     = alltrue([for extension, rule in bunnynet_pullzone_edgerule.content_type : one([for trigger in rule.triggers : trigger.patterns if trigger.type == "Url"]) == tolist(["https://example.com/*.${extension}"])])
    error_message = "Every rule must match files with its extension on the domain, over HTTPS."
  }

  # `MatchNone` would set the type on every other file, including pages.
  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.content_type : one([for trigger in rule.triggers : trigger.match_type if trigger.type == "Url"]) == "MatchAny"])
    error_message = "Every rule's URL trigger must match any of its patterns."
  }
}

# Otherwise, a missing file's `/404.html` would be served with the missing
# file's type.
run "leaves_404s_alone" {
  command = plan

  # `MatchAny` would set the type on every response that isn't a 404, including
  # pages.
  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.content_type : rule.match_type == "MatchAll"])
    error_message = "Every rule must match only when all of its triggers do."
  }

  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.content_type : one([for trigger in rule.triggers : trigger.patterns if trigger.type == "StatusCode"]) == tolist(["404"]) && one([for trigger in rule.triggers : trigger.match_type if trigger.type == "StatusCode"]) == "MatchNone"])
    error_message = "Every rule's status code trigger must match every status except a 404."
  }

  assert {
    condition     = alltrue([for rule in bunnynet_pullzone_edgerule.content_type : length(rule.triggers) == 2])
    error_message = "Every rule must have one URL trigger and one status code trigger."
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
    condition     = alltrue([for extension, rule in bunnynet_pullzone_edgerule.content_type : one([for trigger in rule.triggers : trigger.patterns if trigger.type == "Url"]) == tolist(["https://www.example.com/*.${extension}"])])
    error_message = "With `prefer_www`, every rule must match files with its extension on `www.` and the domain."
  }
}
