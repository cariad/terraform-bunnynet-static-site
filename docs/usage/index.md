# How do I deploy it?

The deployment breaks down into four steps:

1. **[Add your domain to bunny.net](1-add-domain.md)**

    Creates the Bunny DNS zone that your website's DNS records will live in.

1. **[Add the website module](2-add-module.md)**

    Adds the `cariad/terraform-bunnynet-static-site` module to your project.

1. **[Set up state storage](3-state.md)**

    Decides where OpenTofu will keep the record of what it deployed.

1. **[Deploy the website infrastructure](4-deploy.md)**

    Deploys the `cariad/terraform-bunnynet-static-site` module from your project.
