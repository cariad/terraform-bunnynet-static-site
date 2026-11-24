# 3. Set up state storage

When you perform the deployment in the next step, OpenTofu will create a `*.tfstate` file that records the infrastructure's state and secrets. You'll need this file if you ever want to deploy an update to this module, so keep it secret and safe.

The confidential nature of the file means you shouldn't commit it to source control, so you've got two options:

- **Keep the state on your local machine**

    If you plan to deploy only from your local machine then you can take responsibility for manually backing up the state file.

    If this is your choice, then there's nothing to set up here and you can continue to [deployment](4-deploy.md).

- **Keep the state in a remote backend**

    If you want OpenTofu to read and update the state file in a remote data store then you can deploy and configure a [backend](https://opentofu.org/docs/language/settings/backends/configuration/).

    If this is your choice, then now's the time to research, deploy, and configure your backend of choice.

    !!! tip "A paragraph of self-promotion"

        If you'll forgive me, I use [cariad/terraform-scaleway-tofu-state](https://cariad.github.io/terraform-scaleway-tofu-state/) to store my states in [Scaleway](https://www.scaleway.com/).

When you've added a `backend` block to your website's module directory, or when you're sure you don't need a backend, then continue to [deployment](4-deploy.md).
