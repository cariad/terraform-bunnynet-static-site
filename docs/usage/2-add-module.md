# 2. Add the website module

## 2.1. Create the module directory

Create a new "website" module directory, alongside your other infrastructure if you have any.

For example, if you describe your project's infrastructure within an "infra" directory, then create the new "website" directory in there.

```text
your-repository/
└─ infra/
    ├─ other-module-a/
    ├─ other-module-b/
    └─ website/ *
```

!!! info "You don't have to call it "website""

    This guide will refer to the new module as "website", but you can name it anything you like.

## 2.2. Create `main.tf`

Create `main.tf` inside the new module directory.

```text
your-repository/
└─ infra/
    └─ website/
       └─ main.tf *
```

Copy and paste this definition into the file:

```hcl
module "site" {
  source     = "git::https://github.com/cariad/terraform-bunnynet-static-site.git?ref=v0.2.0"
  domain     = "..."
  prefer_www = ...
  zone_name  = "..."
}
```

Set the following values:

- **`source` — URL of `cariad/terraform-bunnynet-static-site`**

    Ensure `ref` is the release that you want to use. Check [Releases](https://github.com/cariad/terraform-bunnynet-static-site/releases) for the latest.

- **`domain` — your domain, without the `www.` prefix**

    For example, regardless of whether you want to host your website at `example.com` or `www.example.com`, set `"example.com"` here.

- **`prefer_www` — whether to make the `www.` subdomain your preferred domain**

    Your website will answer on both `<domain>` and `www.<domain>`, but only your preferred one will host the site. The other will redirect visitors to the page they want on your preferred domain.

    This ensures that every page on your site has a single canonical URL, and you don't lose visitors who accidentally add or omit the `www.` prefix.

    So, for example, if your `domain` is `"example.com"` then choose between:

    | Preferred domain  | Redirect to preferred from | `prefer_www` |
    | -                 | -                          | -            |
    | `www.example.com` | `example.com`              | `true`       |
    | `example.com`     | `www.example.com`          | `false`      |

    !!! danger "Be sure before you launch your site"

        The redirect can be cached by browsers, so changing `prefer_www` later can send returning visitors into a loop between the two domains until they clear their cache.

- **`zone_name` — name of the bunny.net storage zone and pull zone to create**

    The name must be globally unique amongst all bunny.net customers, so consider adding a timestamp or random characters to reduce the chance of a collision.

    For example, use something like `"example-com-20261018"` rather than just `"example"`.

    The name will appear in your `<zone_name>.b-cdn.net` domain name, which means it'll be public knowledge via your DNS records — so don't assume it's secret.

- **`dns_zone` — *optional* name of your domain's DNS zone**

    This is the name of the [DNS zone](https://dash.bunny.net/dns/zones) that you [created earlier](1-add-domain.md#11-create-the-dns-zone).

    You only need to set `dns_zone` if it's not the same as `domain`. For example, if `domain` is a subdomain like `"blog.example.com"`, and the DNS zone is named just `"example.com"`, then you'll need to set `dns_zone` to `"example.com"` here.

## 2.3. Create `versions.tofu`

Create `versions.tofu` inside the new module directory.

```text
your-repository/
└─ infra/
    └─ website/
       ├─ main.tf
       └─ versions.tofu *
```

Copy and paste this configuration into the file:

```hcl
language {
  compatible_with {
    opentofu = ">= 1.12.0, < 1.14.0"
  }
}

terraform {
  required_providers {
    bunnynet = {
      source  = "BunnyWay/bunnynet"
      version = "~> 0.20.2"
    }
  }
}
```

## 2.4. Ignore the module's state and working files

Add these entries to your `.gitignore`:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
```

The code for the website module is done! Now think about [state storage](3-state.md).
