# How do I undeploy it?

!!! danger "This deletes your website"

    Destroying the infrastructure deletes the storage zone and every file in it, along with the pull zone, both custom hostnames, the edge rules and the two DNS records.

If you're *sure* you want to delete everything:

1. Destroy your website's infrastructure:

    !!! warning "Your website module path"

        If you didn't put your website module in `infra/website` then be sure you update the `-chdir=` path before you run the command.

    ```shell
    tofu -chdir=infra/website destroy
    ```

1. Delete the `infra/website` directory.

The module never managed your Bunny DNS zone, so that's left in place.
