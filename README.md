# An OpenTofu module to host a static site in bunny.net

[cariad/terraform-bunnynet-static-site](https://github.com/cariad/terraform-bunnynet-static-site) is an OpenTofu module that serves a static website from [bunny.net].

It's highly-opinionated and intentionally not very configurable. For example:

- The site replicates to every edge region that bunny.net supports.
- Files are cached for five minutes by default, and files with a lowercase SHA256 hash just before their extension (for example, when Hugo fingerprints a file like `main.99ed01e277b426d2d1103c0a04b80e4fa8824f39f1ee453e91511165fb184548.css`) are cached for a year.

## Prerequisites

- Your own [bunny.net] account. You must provision this yourself, and you're responsible for your own charges.

- Your own domain, with DNS hosted on [Bunny DNS](https://bunny.net/dns/) in your account.

- Somewhere to keep the OpenTofu state.

  You might be happy deploying from your local machine and backing up the state manually — but for a more robust approach, I humbly suggest [cariad/terraform-scaleway-tofu-state](https://github.com/cariad/terraform-scaleway-tofu-state).

- [OpenTofu](https://opentofu.org) 1.12 or later.

## Infrastructure

This module creates:

- **A storage zone** that keeps your website's files on SSDs, replicated around the world.
- **A pull zone** that serves the storage zone's files through bunny.net's content delivery network (CDN).
- **Two custom hostnames** on the pull zone and associated DNS records for your domain and its `www.` subdomain, each with a free Let's Encrypt certificate that bunny.net manages and renews.
- **Edge rules** that keep fingerprinted files for a year and redirect visitors to your preferred domain name.

This module won't create your Bunny DNS zone or upload your website. You are responsible for creating the zone, and for uploading your website's files to the storage zone.

## Usage

1. Create a new root module for your website's infrastructure.

   This guide will name the new module `site`, but you can use any name you want.

   ```text
   your-repository/
   └── infra/
       └── site/
   ```

1. Create `infra/site/main.tf`.

   ```hcl
   module "site" {
     source = "git::https://github.com/cariad/terraform-bunnynet-static-site.git?ref=v1.0.0"

     domain     = "example.com"           # Your domain, without "www."
     prefer_www = false                   # Serve from www or bare domain?
     zone_name  = "example-com-20261018"  # The storage and pull zones' name
   }
   ```

   - `source`: Make sure you pin the source `ref` to the specific release you want to deploy. Releases are immutable, so a tag always means the same code.

   - `domain`: Your domain name, without `www.` at the start. For example, `example.com`.

   - `prefer_www`: Your website will answer on both `<domain>` and `www.<domain>`, and `prefer_www` indicates whether you want visitors to `<domain>` redirected to `www.<domain>` (`true`), or for visitors to `www.<domain>` redirected to `<domain>` (`false`).

     Choose before you launch, though. The redirect is permanent, so browsers remember it, and changing `prefer_www` later can send returning visitors round in a loop between the two names until they clear their cache.

   - `zone_name`: The name of the bunny.net storage zone and pull zone.

     It must be 4 to 63 characters long, containing only lowercase letters, digits and hyphens, starting and ending with a letter or digit — and critically, it must be globally unique amongst all bunny.net customers, so consider adding a timestamp or random characters to reduce the chance of a collision. For example, use something like `"example-com-20261018"` rather than just `"example"`.

     The name will appear in your `<zone_name>.b-cdn.net` domain name, which means it'll be public knowledge via your DNS records — so don't assume it's secret.

   - `dns_zone` (optional): Your domain's zone in Bunny DNS.

     This defaults to `domain`, but if your website is on a subdomain (e.g. `blog.example.com`) in another domain's zone (e.g. `example.com`), then set `dns_zone` to that zone.

1. Create `infra/site/versions.tofu`:

   ```hcl
   language {
     compatible_with {
       opentofu = "~> 1.12.0"
     }
   }

   terraform {
     required_providers {
       bunnynet = {
         source  = "BunnyWay/bunnynet"
         version = "~> 0.19.1"
       }
     }
   }
   ```

   Pin the OpenTofu and provider versions you use. The module itself needs OpenTofu 1.12 or later, and a 0.19 release of `BunnyWay/bunnynet` from 0.19.1 onwards. See [Upgrading](#upgrading).

   Name this file `.tofu` rather than `.tf`, because some tools that read `.tf` files fail on a `language` block in a `.tf` file. Don't also create a `versions.tf`, either; when a `.tf` file and a `.tofu` file share a name, OpenTofu ignores the `.tf` file completely.

   You don't need a `provider` block, because `BunnyWay/bunnynet` reads your API key from an environment variable.

1. Unless you're keeping the state in a local file, create `infra/site/backend.tf` to keep it somewhere private.

   If you're using `cariad/terraform-scaleway-tofu-state`, copy the `backend.tf` example from [its usage guide](https://github.com/cariad/terraform-scaleway-tofu-state#usage).

1. Make sure Git ignores OpenTofu's working files.

   ```gitignore
   .terraform/
   *.tfstate
   *.tfstate.*
   ```

   Do commit `.terraform.lock.hcl`, though, because it pins the provider's exact version.

   The code for your website's infrastructure is now done!

1. Make sure your domain's registrar sends its DNS to Bunny DNS, and that the change has propagated.

1. In the bunny.net dashboard, copy your account's API key, and set it as an environment variable in a local shell:

   ```bash
   export BUNNYNET_API_KEY="..."
   ```

   Set whatever credentials your state storage needs, too.

1. Initialise your website's root module.

   ```bash
   tofu -chdir=infra/site init
   ```

1. In your domain's Bunny DNS zone, delete any existing records that would clash with the module's.

   The module creates a `CNAME` record for your domain and another for `www.` your domain. A `CNAME` record can't share its name with any other record — except at the zone's own domain, where Bunny DNS answers for it with addresses instead.

   - At `www.` your domain, delete every record.
   - At your domain, if it's a subdomain in the zone, such as `blog.example.com`, delete every record.
   - At your domain, if it's the zone's own domain, delete any `A`, `AAAA` or `CNAME` records, and any of bunny.net's own Pull Zone, Redirect or Script records.
   - Keep the rest, such as your `MX` and `TXT` records.

   If either name is already a custom hostname on another pull zone, such as one that CDN Acceleration created for an old record, remove it from that pull zone too. A hostname can belong to only one pull zone.

   If the zone's own domain has `CAA` records, they must allow `letsencrypt.org`.

1. Review the plan and apply it:

   ```bash
   tofu -chdir=infra/site apply
   ```

   Now, finally, you're ready to upload your website! See [Caching](#caching) for how to name and upload your files.

## Caching

This module's caching rules are highly-opinionated and strict. Your website's build process must follow these rules, otherwise every file will be cached for only five minutes. If you're okay with that — and it's not a bad default! — then you can ignore this section.

A file is *fingerprinted* when its name is `*.<hash>.<extension>`, where the hash is the SHA-256 of its contents in 64 lowercase hex characters, such as `main.9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08.css`. Hugo's `fingerprint` names files like that by default. The hash has to come straight before the extension.

- **Fingerprinted files are kept for a year**, at the edge and in browsers, whatever their type. Their names change whenever their contents do, so a visitor never gets an old copy.
- **Everything else is kept at the edge for five minutes**, and browsers check with the edge before reusing it. That includes pages, feeds, and files with shorter hashes, uppercase hashes, or hashes elsewhere in their names.
- **You don't need to purge the cache**, or to give your deploy the account's API key. Once a file's five minutes are up, the next request for it still gets the old copy while the edge fetches the new one.
- **While the storage zone is unreachable**, or while the edge fetches a newer copy of a file, bunny.net serves the copy it has.
- **Missing files get your website's `/404.html`**, with a 404 status. Until you upload one, bunny.net serves its standard 404 page. Neither the edge nor browsers keep a 404, so once you upload the missing file, the next request gets it.

When you deploy:

1. Upload fingerprinted files before the pages that refer to them, so that a page never refers to a file that isn't there yet. Start uploading pages once every fingerprinted file's upload has finished, but you don't need to wait any longer than that. Uploads reach Germany first. bunny.net says they reach the other regions within a couple of seconds, with no guarantee, and that until then, it serves a new file from a region that has it. If a visitor does ask for a file too early, the 404 isn't kept, so their next request gets the file.
1. Never change a fingerprinted file without renaming it. A purge would clear the old copy from the edge, but not from browsers.
1. Don't delete old fingerprinted files straight away. Pages still cached at the edge, which can be more than five minutes old, and stylesheets in browsers' caches, can still refer to them.
1. Upload `.webmanifest` files with a `Content-Type` of `application/manifest+json`. bunny.net doesn't recognise the extension, so without one it serves them as `application/octet-stream`.

## Upgrading

Each release is a GitHub release with an immutable tag, and its [release notes](https://github.com/cariad/terraform-bunnynet-static-site/releases) describe what changed. To upgrade, change `ref` in the module's `source`, run `tofu -chdir=infra/site init` to download the new version, then plan and apply.

The module accepts provider versions from 0.19.1 up to, but not including, 0.20.0. The bunny.net provider doesn't promise semantic versioning, and its 0.x minor releases have often included breaking changes, so the module won't accept a new minor release until it's been tested against it. When it has, a new release of this module widens the range to include it, and you can then raise your own pin whenever you're ready.

Dependabot's `opentofu` ecosystem can open pull requests to upgrade the module. It names a Git module `<module label>::github::<owner>/<repo>::<ref>`, so an `allow` rule that limits it to this module needs wildcards:

```yaml
version: 2

updates:
  - allow:
      - dependency-name: "*::github::cariad/terraform-bunnynet-static-site::*"
    directories:
      - /infra/site
    package-ecosystem: opentofu
    schedule:
      interval: weekly
```

## Retiring the website

If you're *sure* you want to delete everything:

1. Destroy your website's infrastructure. This deletes the storage zone, and every file in it, along with the pull zone, both custom hostnames, the edge rules and the two DNS records.

   ```bash
   tofu -chdir=infra/site destroy
   ```

1. Delete the `module "site"` block, or the whole `infra/site` directory — otherwise, the next apply would create everything again.

## AI disclosure

This project is developed by me, Cariad Eccleston, with the assistance of:

- *Claude Opus 5.5* in Claude Code for research, code, tests, and reviews
- *GitHub Copilot* for reviews

I own the scope and requirements of the project, and I make the design decisions: the interfaces, the structure, and the trade-offs.

Claude writes the first drafts of code and tests, which I review for correctness and quality, then revise with Claude or by hand.

Claude writes the first draft of documentation, which I rewrite in my own voice.

When I'm satisfied, Claude reviews the workspace, and we act *only* on the feedback that I agree with, before I check my understanding and commit.

Finally, Copilot and I review every pull request, before I merge it.

I retain full responsibility for all changes that land in the `main` branch.

AI-assisted contributions are welcome — see [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Licence

MIT. See [`LICENSE`](LICENSE).

[bunny.net]: https://bunny.net
