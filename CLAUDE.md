# CLAUDE.md

An OpenTofu module (not Terraform) that serves a static website from bunny.net: an Edge-tier storage zone replicated to every Edge region, a pull zone that serves it, custom hostnames with TLS for the bare domain and `www.`, their two Bunny DNS records, and edge rules that keep files with certain extensions for a year, set the content type of certain extensions bunny.net doesn't recognise, redirect to the preferred hostname, and redirect `<zone_name>.b-cdn.net`.

## Commands

```bash
mise install                                           # Install the pinned tools
mise run lint                                          # Every linter, stopping at the first failure
mise run test                                          # tofu test, mostly with a mock provider (runs lint:tofu first to initialise)
mise exec -- tofu test -filter=tests/domain.tftest.hcl # One test file
mise exec -- tofu fmt -recursive                       # Fix OpenTofu formatting
mise exec -- tombi format .                            # Fix TOML formatting
```

## Keep in sync

- After changing `[tools]`, run `mise lock`.
- Update the README with any change to inputs, resources, DNS records, redirects, caching or versions. Resources are listed in both "Infrastructure" and "Retiring the website". The intro and "Caching" both list the year-long extensions.
- The README's example pins OpenTofu `~> 1.12.0`. Dependabot's `opentofu` updater bundles 1.12.1, so neither that pin nor the floor in `versions.tofu` may rise past 1.12.
- When widening the provider range, check in the provider's source that these still hold:
  - The Edge tier's regions (`internal/storagezoneresourcevalidator/region.go`) match those the bunny.net dashboard offers when adding a storage zone. bunny.net's docs and API don't give a reliable list.
  - Storage zone deletion (`internal/api/storage_zone.go`).
  - A hostname's `force_ssl`, and an edge rule's `actions` and `triggers`, update in place.
  - The pull zone's cache defaults, including `cache_errors`, and `IgnoreQueryStrings = true` when `cache_vary` is unset (`internal/provider/resource_pullzone.go`).
  - Edge rules read `""` back as `null`, and the `StatusCode` trigger type exists.
  - DNS records take the zone's own domain as the name `""`, leave `weight` null for a `CNAME`, are replaced by a new `zone`, `name` or `type`, and have no default for `accelerated`.
  - The DNS zone data source looks up the exact domain, in the API key's account only, and calls the API even when planning.

## Decisions not to undo

- The lower bounds in `versions.tofu` aren't tested. Check them before using a newer OpenTofu or provider feature.
- No outputs until something needs one.
- `domain`, `prefer_www` and `zone_name` stay required, with no defaults. Use `local.dns_zone`, never `var.dns_zone`.
- `domain` stays lowercase, because the provider compares it case-sensitively with the hostname bunny.net returns.
- Changing `zone_name`, or the storage zone's tier or main region, replaces callers' zones, and bunny.net deletes a storage zone's pull zones with it. Treat any of these as a breaking change.
- A replication region can be added but never removed, so a release that adds one can't be rolled back.
- The README's record-clearing step rests on live checks against Bunny DNS, not bunny.net's docs. Don't "correct" it from the docs.
- Hard-code `b-cdn.net` rather than using the pull zone's `cdn_domain`, so values are known at plan and testable under the mock.
- Never set the pull zone's edge cache time to 0, which bypasses the cache.
- Bunny Storage can't store `Cache-Control`, so caching stays in edge rules. Set `Content-Type` in edge rules only for extensions bunny.net doesn't recognise, such as `.webmanifest`.
- The year-long rules use `Url` wildcard triggers, not `UrlExtension`, which can't restrict the hostname. Never trigger on `Content-Type`.
- If a 404 is ever seen kept at the edge, the README's "Upload order" section is wrong.
- bunny.net runs only the first matching action of each short-circuiting type, such as `OverrideCacheTime`, `OverrideBrowserCacheTime` or `Redirect`, in creation order. Never let two rules use the same one of those types on the same URL, and don't set `priority`, which is untested.
- Unused action and trigger parameters are `null`, never `""`. Action and trigger types are literals, because `tofu validate` fails on one it can't know.

## Conventions

- Within a block, sort arguments alphabetically, then nested blocks, then meta-arguments such as `count` and `depends_on` after a blank line. Sort variables and list items too.
- Validation error messages spell out the rule. Precondition messages stay short.
- Say "the storage zone" or "the pull zone" wherever "zone" alone would be ambiguous.
- Keep the mocks' non-zero IDs: the provider rejects `origin.storagezone = 0` even under a mock.
- The mock runs the provider's validation but not its defaults, so assert only on values the module sets or the mock defines.
- The README is in the maintainer's own voice. Change only what a task needs, and ask before rewriting their wording.
- British spelling.
