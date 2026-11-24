# How do I upgrade it?

Each release of the `cariad/terraform-bunnynet-static-site` module is a GitHub release with an immutable tag, and its [release notes](https://github.com/cariad/terraform-bunnynet-static-site/releases) describe what changed.

To upgrade your infrastructure to a later release:

1. Change `ref` in the module's `source` in [`main.tf`](usage/2-add-module.md#22-create-maintf).
1. Update the OpenTofu and provider versions in [`versions.tofu`](usage/2-add-module.md#23-create-versionstofu) to match the ones in the guide.
1. Download the new versions:

    !!! warning "Your website module path"

        If you didn't put your website module in `infra/website` then be sure you update the `-chdir=` path before you run the command.

    ```shell
    tofu -chdir=infra/website init -upgrade
    ```

1. Review the changes:

    ```shell
    tofu -chdir=infra/website plan
    ```

1. Apply the changes:

    ```shell
    tofu -chdir=infra/website apply
    ```

The bunny.net provider doesn't promise semantic versioning, and its 0.x minor releases have often included breaking changes, so the module won't accept a new minor release until it's been tested against it.

When it has, a new release of this module moves the range to include it.

## Upgrading with Dependabot

Dependabot's `opentofu` ecosystem can open pull requests to upgrade the module. It names a Git module `<module label>::github::<owner>/<repo>::<ref>`, so an `allow` rule that limits it to this module needs wildcards:

```yaml
version: 2

updates:
  - allow:
      - dependency-name: "*::github::cariad/terraform-bunnynet-static-site::*"
    directories:
      - /infra/website
    package-ecosystem: opentofu
    schedule:
      interval: weekly
```
