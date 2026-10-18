mock_provider "bunnynet" {
  mock_data "bunnynet_dns_zone" {
    defaults = {
      id = 3
    }
  }

  mock_resource "bunnynet_pullzone" {
    defaults = {
      id = 2
    }
  }

  mock_resource "bunnynet_storage_zone" {
    defaults = {
      id = 1
    }
  }
}

variables {
  domain     = "example.com"
  prefer_www = false
  zone_name  = "example-site"
}

run "adds_both_hostnames_to_the_pull_zone" {
  command = plan

  assert {
    condition     = bunnynet_pullzone_hostname.bare.name == "example.com" && bunnynet_pullzone_hostname.www.name == "www.example.com"
    error_message = "The hostnames must be the domain, and `www.` and the domain."
  }

  assert {
    condition     = bunnynet_pullzone_hostname.bare.pullzone == bunnynet_pullzone.site.id && bunnynet_pullzone_hostname.www.pullzone == bunnynet_pullzone.site.id
    error_message = "Both hostnames must belong to the module's pull zone."
  }

  assert {
    condition     = bunnynet_pullzone_hostname.bare.tls_enabled && bunnynet_pullzone_hostname.www.tls_enabled
    error_message = "Both hostnames must have TLS."
  }
}

# Only the preferred hostname forces HTTPS, because the www redirect sends HTTP
# requests for the other one straight to HTTPS on the preferred hostname.
run "forces_https_on_the_bare_domain_when_it_is_preferred" {
  command = plan

  assert {
    condition     = bunnynet_pullzone_hostname.bare.force_ssl && !bunnynet_pullzone_hostname.www.force_ssl
    error_message = "Without `prefer_www`, only the bare hostname must force HTTPS."
  }
}

run "forces_https_on_www_when_it_is_preferred" {
  command = plan

  variables {
    prefer_www = true
  }

  assert {
    condition     = bunnynet_pullzone_hostname.www.force_ssl && !bunnynet_pullzone_hostname.bare.force_ssl
    error_message = "With `prefer_www`, only the www hostname must force HTTPS."
  }
}
