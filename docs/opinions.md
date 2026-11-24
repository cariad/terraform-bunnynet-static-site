# Opinions

The `cariad/terraform-bunnynet-static-site` module is highly-opinionated and intentionally not very configurable.

Make sure you're happy with these decisions before you deploy it, because you can't change them.

- **Your website is replicated to every edge region that bunny.net supports**

    Unless you're deploying gigabytes on gigabytes, the cost per region is pennies. Pennies × 15 regions is still pennies, so the module prioritises reducing latency.

- **Images, fonts, stylesheets, scripts and media are cached for a year**

    Files named `*.avif`, `*.css`, `*.gif`, `*.jpeg`, `*.jpg`, `*.js`, `*.mjs`, `*.mp3`, `*.mp4`, `*.otf`, `*.pdf`, `*.png`, `*.svg`, `*.ttf`, `*.wasm`, `*.webm`, `*.webp`, `*.woff` and `*.woff2` are cached in the CDN and the browser for a year.

    You're expected to [fingerprint these files](upload.md#fingerprint-your-long-cached-files) — using, for example, [Hugo](https://gohugo.io/)'s [`fingerprint`](https://gohugo.io/functions/resources/fingerprint/) function — to ensure the filename changes if the content changes.

- **Everything else is cached for five minutes**

    Every other type of file (like `*.html`) and files with uppercase extensions (like `*.JPG`) are cached for only five minutes.

- **Your website answers on both your domain and its `www.` subdomain**

    You [choose which one you prefer](usage/2-add-module.md#22-create-maintf), and the other redirects visitors to it.

- **Your domain's DNS is hosted by Bunny DNS**

    The module creates your website's DNS records in a [Bunny DNS](https://bunny.net/dns/) zone in your own account.

If these suit you, then find out [what the module deploys](infrastructure.md).
