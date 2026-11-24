# Development setup

!!! warning "Contributors only"

    You don't need this document if you just want to use the module. See [Usage] instead.

    If you're reading this to contribute a code change to this project, please read [Contributing] first.

[Contributing]: contributing.md

[Usage]: usage/index.md

## Prerequisites

- [mise](https://mise.jdx.dev/) 2026.11.8 or later

## Initial setup

1. Clone this repository.

    ```shell
    git clone git@github.com:cariad/terraform-bunnynet-static-site.git
    cd terraform-bunnynet-static-site
    ```

1. Install the project's tools.

    ```shell
    mise install
    ```

## Linting and testing

Most tests use a mock provider, and the rest only plan with the real one, so they don't need a bunny.net API key.

```shell
mise run lint
mise run test
```

## Documentation

This documentation site is built from `docs/` by [Zensical](https://zensical.org), and configured in `zensical.toml`.

To preview the site at <http://localhost:8000/terraform-bunnynet-static-site/> while you edit it:

```shell
mise run docs:serve
```

CI builds the site in strict mode, so a warning, such as a broken link, fails the build. To check the build before you push:

```shell
mise run docs:build
```

## Releasing

1. Update the `ref` in the usage example to the new release's tag, and merge that change into `main`.
1. Publish a GitHub release for `main`.
