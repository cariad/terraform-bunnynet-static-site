# What do I need?

- **Your own [bunny.net] account**

    You must provision this yourself, and you're responsible for your own charges.

    bunny.net API keys are account-wide, so I recommend creating a new account for each project to limit the blast radius of a leaked key.

- **Your own domain**

    Its DNS must be hosted by [Bunny DNS](https://bunny.net/dns/) in your account. If it isn't there yet, the deployment guide starts by [adding it](usage/1-add-domain.md).

- **Somewhere to keep the OpenTofu state**

    You might be happy deploying from your local machine and backing up the state manually.

    !!! tip "A more robust approach"

        I humbly suggest [cariad/terraform-scaleway-tofu-state](https://cariad.github.io/terraform-scaleway-tofu-state/), which stores OpenTofu state in [Scaleway].

- **[OpenTofu](https://opentofu.org) 1.12 or later**

[bunny.net]: https://bunny.net

[Scaleway]: https://www.scaleway.com
