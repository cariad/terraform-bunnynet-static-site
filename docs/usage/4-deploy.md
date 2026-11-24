# 4. Deploy the website infrastructure

!!! warning "Check your nameservers first"

    Make sure your domain's [nameserver change has propagated](1-add-domain.md#12-wait-for-propagation) before you continue, otherwise the deployment will fail.

## 4.1. Set environment variables

Log into [bunny.net](https://bunny.net/) and get [your API key](https://dash.bunny.net/account/api-key).

Set your API key as the `BUNNYNET_API_KEY` environment variable in a local shell:

```shell
export BUNNYNET_API_KEY="..."
```

!!! info "State backend credentials"

    Also make sure you've set any environment variables that your state backend needs — for example, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` for S3-compatible object storage.

## 4.2. Initialise the website module

!!! warning "Your website module path"

    If you didn't put your website module in `infra/website` then be sure you update the `-chdir=` path before you run the command.

Run `tofu` to initialise the website module:

```shell
tofu -chdir=infra/website init
```

If it succeeds, then you should see a message like:

```text
OpenTofu has been successfully initialized!
```

## 4.3. Remove any existing domain records

Open the [DNS Zones console](https://dash.bunny.net/dns/zones), open your domain's zone, then:

- Delete every record named `www.<domain>`.
- If `<domain>` is a subdomain, like `blog.example.com`, delete every record named `<domain>`.
- Otherwise, delete any `A`, `AAAA`, `CNAME`, Pull Zone, Redirect and Script records named `<domain>`. **Keep the rest, like `MX` and `TXT`.**
- If you have any `CAA` records, check they allow `letsencrypt.org`.

If `<domain>` or `www.<domain>` is a custom hostname on another pull zone, remove it from that pull zone too.

## 4.4. Review and apply the deployment

!!! warning "Your website module path"

    If you didn't put your website module in `infra/website` then be sure you update the `-chdir=` path before you run the command.

Run `tofu` to review then deploy the website module:

```shell
tofu -chdir=infra/website apply
```

If it succeeds, then you should see a message like:

```text
Apply complete! Resources: 17 added, 0 changed, 0 destroyed.
```

With that done, the website infrastructure is deployed! Now you can [upload your website](../upload.md).
