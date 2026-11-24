# What does it deploy?

In your [bunny.net](https://bunny.net/) account, the `cariad/terraform-bunnynet-static-site` module creates:

- **A storage zone**

    Stores your website on fast SSDs, replicated around the world.

- **A pull zone**

    Serves your website through bunny.net's global content delivery network (CDN).

- **Two custom hostnames and their DNS records**

    Your domain and its `www.` subdomain, each with a free SSL certificate that bunny.net manages and renews.

- **Edge rules**

    Cache files, set the content types of extensions that bunny.net doesn't recognise, and redirect visitors to your preferred domain name.

The module won't create your Bunny DNS zone or upload your website. You're responsible for [creating the zone](usage/1-add-domain.md), and for [uploading your files](upload.md) to the storage zone.
