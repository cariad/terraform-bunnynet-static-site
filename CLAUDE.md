# CLAUDE.md

An OpenTofu module (not Terraform) that serves a static website from bunny.net: an Edge-tier storage zone replicated to every Edge region, a pull zone that serves it, custom hostnames with TLS for the bare domain and `www.`, their two Bunny DNS records, and edge rules that keep fingerprinted files for a year, redirect to the preferred hostname, and redirect `<zone_name>.b-cdn.net`.

## Commands

```bash
mise install                                           # Install the pinned tools
mise run lint                                          # Every linter, stopping at the first failure
mise run test                                          # tofu test, mostly with a mock provider (runs lint:tofu first to initialise)
mise exec -- tofu test -filter=tests/domain.tftest.hcl # One test file
mise exec -- tofu fmt -recursive                       # Fix OpenTofu formatting
mise exec -- tombi format .                            # Fix TOML formatting
```

CI runs each `lint:*` task as its own step, then `mise run --skip-deps test`, so a new linter also needs a step in `.github/workflows/ci.yml`.

## Keep in sync

- `.config/mise.toml`•`min_version` ↔ `.github/workflows/ci.yml`'s mise-action `version` ↔ the mise schema URL in `.config/tombi.toml`.
- `.config/mise.toml`•`tools`•`rumdl` ↔ the rumdl schema URL in `.config/tombi.toml`.
- After changing `[tools]`, run `mise lock`, because CI sets `MISE_LOCKED=1`.
- `.terraform.lock.hcl` is committed, and `lint:tofu` initialises with `-lockfile=readonly`. Update it with `mise exec -- tofu init -backend=false -upgrade`.
- The provider range in `versions.tofu` ↔ the README's usage step and "Upgrading" section, which state it in words ↔ the README's example `versions.tofu`, which pins the provider to the range's lower bound (`~> 0.19.1`) and OpenTofu to `~> 1.12.0`. Don't raise that OpenTofu pin above the version Dependabot's `opentofu` updater bundles (1.12.1), or callers' Dependabot updates fail.
- The OpenTofu floor in `versions.tofu` (`>= 1.12.0`) ↔ the README's "Prerequisites" and usage step, which both say "1.12 or later" ↔ the example's `~> 1.12.0` pin, which must overlap it. That pin can't rise above 1.12.1, so a floor of 1.13 or later would break the example and callers' Dependabot updates.
- `variables.tf` ↔ the README's `main.tf` usage step, which explains every input. There's no inputs table. The example leaves out the optional `dns_zone`, and the bullets explain it last.
- The hostname regex in `dns_zone`'s validation ↔ the one in `domain`'s, which it copies.
- What `prefer_www` chooses (`local.preferred_hostname` in `hostnames.tf`, and `www_redirect.tf`) and the redirects' `301` ↔ the README's `prefer_www` bullet, including its warning that the redirect is permanent.
- The DNS records in `dns.tf` and the hostnames in `hostnames.tf` ↔ the README's "Infrastructure" section and the usage step that clears existing records.
- The edge rules (`fingerprinted_files.tf`, `www_redirect.tf` and `cdn_hostname_redirect.tf`) ↔ the README's "Infrastructure" section ↔ this file's opening line.
- The year-long URL pattern in `fingerprinted_files.tf` ↔ the README's description of fingerprinted files (its intro and "Caching" section) ↔ the literal pattern in `tests/year_long.tftest.hcl`.
- The pull zone's cache settings (`cache_errors`, `cache_expiration_time`, `cache_expiration_time_browser` and `cache_stale`), the storage zone's `custom_404_file_path` and the year-long rules ↔ the README's "Caching" section.
- Every resource in the module ↔ the README's "Retiring the website" step, which lists what `destroy` deletes.
- The test files each repeat the same `mock_provider` block, because OpenTofu has no shared mocks, and the same `variables` block, so each file reads on its own. `tests/real_provider.tftest.hcl` has no mock, and an `override_data` block for the DNS zone instead.
- When widening the provider range, check everything the module relies on in the provider's source:
  - The Edge tier's regions in `internal/storagezoneresourcevalidator/region.go`, against the Edge regions the bunny.net dashboard offers when adding a storage zone. That's the only reliable list: bunny.net's tier docs leave out `UK`, and the documented `GET /storagezone/regions` endpoint answers "The request is invalid."
  - Storage zone deletion (`internal/api/storage_zone.go`).
  - A hostname's `force_ssl`, and an edge rule's `actions` and `triggers`, updating in place (`internal/provider/resource_pullzone_hostname.go`, `internal/provider/resource_pullzone_edgerule.go`).
  - The pull zone's cache defaults, including `cache_errors`, and query strings staying out of its cache key (`internal/provider/resource_pullzone.go`): with `cache_vary` unset, the provider sends `IgnoreQueryStrings = true`. So query strings such as tracking parameters don't split the edge's cache, and `?v=` doesn't bust the edge's copy of a file.
  - Edge rules reading `""` back as `null` (`internal/provider/resource_pullzone_edgerule.go`), and the `StatusCode` trigger type (`internal/pullzoneedgeruleresourcevalidator/types.go`).
  - DNS records (`internal/provider/resource_dns_record.go`, `internal/dnsrecordresourcevalidator/`): the zone's own domain as the name `""`, `weight` left null for a `CNAME`, a new `zone`, `name` or `type` replacing the record, and `accelerated` having no default.
  - The DNS zone data source's lookup by exact domain, among only the API key's account's zones, which calls the API even when planning (`internal/provider/datasource_dns_zone.go`, `internal/api/dnszone.go`).

## Decisions not to undo

### Versions and interface

- The OpenTofu version constraint is a `language { compatible_with { opentofu = ... } }` block, not the legacy `required_version`. It lives in `versions.tofu` because Terraform, and tools that read only `.tf` files, fail on it in a `.tf` file. Providers stay in `terraform { required_providers }`, as a range, not a pin.
- The provider range stops before the next minor release (`< 0.20.0`), because the provider doesn't promise semantic versioning and its 0.x minor releases often break things. Widen it in a release once the tests pass against the new minor release.
- The lower bounds in `versions.tofu` aren't tested. Before using a newer OpenTofu or provider feature, check that the lower bound has it, or raise the bound in a release.
- The module has no `provider`, `backend` or `import` blocks. Callers configure the provider and keep the state in their own root module. It has no outputs, because nothing needs them yet.
- Once a version is released, renaming a resource needs a `moved` block, because callers' state holds the old address.
- `domain`, `prefer_www` and `zone_name` are required, with no defaults, so nothing in the module identifies a caller or a website, and every caller chooses whether to prefer `www.`. `dns_zone` is optional, and null means `domain`, because most websites are on their zone's own domain. `local.dns_zone` holds the result, so use it, never `var.dns_zone`.
- `domain` is the bare domain: it can't start with `www.`, and it's at most 249 characters, so that `www.` fits within a hostname's 253. It must be lowercase, because the provider compares it case-sensitively with the hostname bunny.net returns.
- `zone_name` names both the storage zone and the pull zone, and is public as `<zone_name>.b-cdn.net`. Changing it replaces both zones and both custom hostnames, so treat it as a breaking change.

### Hostnames and DNS

- The website always answers on both `<domain>` and `www.<domain>`, because people type and link `www.` out of habit, and Chrome adds it on Ctrl+Enter.
- A caller's domain must be on Bunny DNS. A zone's own domain can't have an ordinary `CNAME`, bunny.net doesn't support `A` records to its IPs, and Bunny DNS's `CNAME` flattening is the route bunny.net documents and recommends. Other DNS hosts' flattening or `ALIAS` records aren't supported.
- The module adds two `CNAME` records to the caller's existing Bunny DNS zone, which it looks up by `local.dns_zone` with the `bunnynet_dns_zone` data source. The zone and its other records stay the caller's. A precondition on the data source checks that `domain` is in the zone. The data source finds only zones in the API key's account, so the zone must be in the website's account.
- At the zone's own domain, bunny.net's API accepts the `CNAME` while `MX`, `TXT` and `CAA` records already exist there, and Bunny DNS keeps serving them, with the `CNAME` flattened into `A` and `AAAA` answers. A spare-zone test with provider 0.19.2 confirmed this on 2026-10-18, so the README tells callers to keep those records. The API refuses a `CNAME` where an `A` record exists (the provider's issue #62), so the README tells callers to delete address records. Below the zone's own domain, Bunny DNS doesn't flatten, so a `CNAME` hides every other record at its name, and the README tells callers to delete them all. bunny.net documents only the flattening into `A` and `AAAA` answers, not the other records alongside the `CNAME`, the refusal, or what happens below the zone's own domain.
- The records have CDN Acceleration off (`accelerated = false`), because it would put the names on a separate pull zone. Each hostname `depends_on` its DNS record, so its certificate is requested after the record exists.
- The hostname resources are named `bare` and `www`, not by role, so changing `prefer_www` updates them in place rather than replacing them. Only the preferred one forces HTTPS: `www_redirect.tf` sends the other one's HTTP requests straight to HTTPS on the preferred hostname, in one hop.
- The redirects are permanent (`301`), so browsers remember them. Changing `prefer_www` after launch can send returning visitors round in a loop between the two hostnames, so the README tells callers to choose before launch.
- `www_redirect.tf` matches only when both its triggers do (`MatchAll`), and its second trigger (`MatchNone`) leaves Let's Encrypt's challenges unredirected, so bunny.net can renew the redirected hostname's certificate. With `MatchAny`, it would redirect every other request, including the preferred hostname's, in a loop.
- The edge rules use `local.preferred_hostname` and `local.redirected_hostname`, which come from the hostname resources, so OpenTofu creates the rules only after both hostnames and their certificates.
- The `<zone_name>.b-cdn.net` redirect (`cdn_hostname_redirect.tf`) and both DNS records (`dns.tf`) hard-code `b-cdn.net`, rather than using the pull zone's `cdn_domain` (whose value is `b-cdn.net`), so their values are known at plan and testable under the mock.

### Storage and TLS

- The storage zone is in the Edge tier, on SSDs, because the pull zone's five-minute cache means it fetches from storage often. The Edge tier's only main region is `DE`, so there's no region input. Changing the tier or the main region would replace callers' storage zones, and bunny.net deletes a storage zone's pull zones along with it.
- The storage zone replicates to every other Edge region, because the cost is worth not having to decide it per site. bunny.net allows at most 15 Edge regions, including `DE`, so the module uses them all. A replication region can be added but never removed: the provider fails at apply if one is. So a release that adds a region can't be undone, and callers can't go back to an earlier release afterwards. A new region also needs a provider release whose `edgeRegions` (`internal/storagezoneresourcevalidator/region.go`) has its code.
- The pull zone accepts only TLS 1.2 and newer, with only forward-secret key exchange and AEAD ciphers (`tls_level = "ModernOnly"`). The provider defaults to the `Legacy` level, which also allows RSA key exchange and SHA-1 CBC ciphers. `tls_support` keeps its default, which turns on TLS 1.0 and 1.1, because bunny.net rejects both at the Modern only level regardless.

### Caching

- The caching is opinionated, and callers can't change it. The pull zone keeps files at the edge for 300 seconds and browsers revalidate (`0`), so a deploy goes live without a purge, which would need the account's API key. Not 0 at the edge, which bypasses the cache. The provider's default, -1, would leave storage zone files at the edge for bunny.net's default of a month.
- `cache_errors` stays false, the provider's default. The README's promise that a 404 is never kept depends on it.
- Only URLs on the preferred hostname, over HTTPS, whose last segment is `<name>.<64 lowercase hex characters>.<extension>`, get a year. The pattern's `.*` lets the name be empty. Every other file falls back to five minutes, so a file that isn't fingerprinted is never stuck for a year. The rules use bunny.net's Lua pattern matching (`pattern:`), which has no counted repeats, so `[0-9a-f]` is written out 64 times. In Lua patterns, `-` is a repeater, so the domain's hyphens are escaped as well as its dots.
- The year is two rules in `fingerprinted_files.tf`. `year_long_in_browsers` sets `OverrideBrowserCacheTime` on the URL alone. `year_long_at_the_edge` sets `OverrideCacheTime` only when the URL matches and the status is `200` (`MatchAll` with a `StatusCode` trigger). bunny.net documents none of the reasons, which rest on bunny.net sites probed on 2026-10-18, and on reasoning from what was seen:
  - On a pull zone set up like this module's, with the URL trigger alone, the edge kept a 404 for a fingerprinted URL far longer than five minutes, although `cache_errors` was false. A visitor who asks for a file before it's uploaded could pin its 404 at their edge location for up to a year, and nothing purges it.
  - On another bunny.net site, whose browser rule is gated on `200`, a `304` carried `max-age=0`. Browsers copy a `304`'s headers onto their stored copy (RFC 9111 §4.3.4), so they would then revalidate the file on every use. That part is reasoned, not seen. bunny.net already sends a 404 with `no-cache`, so the browser rule needs no gate.
  - The gate has been seen working on that other site, but not yet on this module's own pull zone. After a real deploy, three `curl -sI` requests for a made-up fingerprinted URL should each be a cache MISS. If they aren't, revisit the no-wait decision below and the README's "When you deploy" step 1.
  - Untested: if the status the trigger sees isn't `200`, that edge location should keep the file for five minutes instead, which only costs extra fetches from storage. That could happen if a visitor's conditional or range request is what fills an empty edge, or if bunny.net revalidates its own expired copy and gets a `304`.
- Edge rules match on `Url` triggers, never on a `Content-Type` response header, because bunny.net knows the URL before it fetches a file, and the header only after. The year-long edge rule's `StatusCode` trigger is the one exception, for the reasons above.
- bunny.net runs only the first matching action of each short-circuiting type, such as `OverrideCacheTime`, `OverrideBrowserCacheTime` or `Redirect`. The rules leave the provider's `priority` (bunny.net's `OrderIndex`) unset, so they run in creation order, which OpenTofu doesn't fix. So no two rules may use the same one of those action types on the same URL. Keep rules from overlapping rather than ordering them, because a non-zero `priority` is untested here. `SetResponseHeader` applies from every matching rule.
- A trigger has at most five patterns, bunny.net's default limit. The provider doesn't check this, and what bunny.net does with a sixth is undocumented.
- Unused action and trigger parameters are `null`, never `""`, because the provider reads `""` back as `null`. Action and trigger types are literals, because `tofu validate` fails on an action type it can't know.
- The module sets no `Content-Type`. Uploads can set their own on each `PUT`, and the README's "When you deploy" steps list the ones callers must set. Whether bunny.net serves a custom type exactly as uploaded is untested. Bunny Storage keeps no `Cache-Control`, though, so caching stays in the module.
- Deploys need no timed wait between fingerprinted files and pages, because the edge shouldn't keep a 404 (which rests on the `200` gate above), and bunny.net says a region without a new file serves it from one that has it. That second claim appears only on bunny.net's Stream replication page.

## Conventions

- Within a block, arguments are sorted alphabetically, then nested blocks follow, then meta-arguments such as `depends_on`, after a blank line. Variables and list items are sorted too.
- Variables are `nullable = false` with no default, except optional ones, which are `nullable = true` with `default = null`, because OpenTofu rejects a null default when `nullable = false`. Their validation starts with `var.<name> == null ||`, because `||` drops the errors that a null causes on its right.
- Comments briefly explain *why*.
- Each kind of edge rule has its own file, named for what it does. `fingerprinted_files.tf` holds both year-long rules, which share its URL pattern.
- Validation error messages spell out the rule, because a failure shows the caller's argument, not the condition. Precondition messages stay short, because a failure shows the condition.
- Say "the storage zone" or "the pull zone" wherever "zone" alone would be ambiguous.
- Tests mock the storage zone's ID as 1, the pull zone's as 2 and the DNS zone's as 3. The provider rejects a pull zone whose `origin.storagezone` is 0, even under a mock, and different IDs let the tests check which resource refers to which.
- The mock provider still runs the real provider's validation at plan, so a value a test expects to be accepted must pass the provider's checks too, such as the Edge tier's rules for the storage zone's regions. The mock doesn't apply the provider's defaults: it fills unset computed attributes with `false`, `0`, empty collections or random strings. So assert only on values the module sets or the mock defines, and not on one the mock would also invent, such as `cache_expiration_time_browser = 0`.
- `tests/real_provider.tftest.hcl` checks those values, such as the browser cache time and the DNS records' `accelerated = false`, and the provider defaults the module relies on, such as `cache_errors`, the pull zone's routing tier and the storage zone's type. It makes no API calls when it plans new resources, so it needs no API key. It can assert only on values from the configuration or the provider's defaults, because computed values are unknown in a real plan. Every run in it must set `command = plan`, because a run without it applies, and its `provider` block points at a host that can't exist in case one ever does.
- `expect_failures` runs use `command = plan`, make exactly one thing invalid, and have no `assert` blocks.
- The README is in the maintainer's own voice. Change only what a task needs, and ask before rewriting their wording.
- Use British spelling.
- There's no `CHANGELOG.md`. `CONTRIBUTING.md` describes releasing.
