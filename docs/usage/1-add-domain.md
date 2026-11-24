# 1. Add your domain to bunny.net

## 1.1. Create the DNS zone

Log into [bunny.net](https://bunny.net) and open the [DNS Zones console](https://dash.bunny.net/dns/zones).

Click **Add DNS Zone**, then follow the instructions to add your domain.

Don't forget to update your domain's nameservers at your domain registrar to complete the handoff to bunny.net.

## 1.2. Wait for propagation

Nameserver changes can take several days to propagate.

You can check your change's progress across the world by looking up your domain's `NS` records on websites like [dnschecker.org](https://dnschecker.org/#NS/).

!!! warning "Wait before you deploy"

    You must wait for the new nameservers to be widely propagated before performing the deployment.

    bunny.net requests your website's SSL certificates during the deployment, and that fails if your domain doesn't resolve through Bunny DNS yet.

In the meantime, though, you can [add the website module to your project](2-add-module.md).
