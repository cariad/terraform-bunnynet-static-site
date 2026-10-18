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

run "serves_the_storage_zone" {
  command = plan

  assert {
    condition     = bunnynet_pullzone.site.origin.type == "StorageZone"
    error_message = "The pull zone's origin must be a storage zone."
  }

  assert {
    condition     = bunnynet_pullzone.site.origin.storagezone == bunnynet_storage_zone.site.id
    error_message = "The pull zone must serve the module's storage zone."
  }
}

# `tests/real_provider.tftest.hcl` checks the browser cache time and the routing
# tier, because the mock can't: it would give the browser cache time the same
# value if the module stopped setting it, and doesn't apply the tier's default.
run "keeps_files_at_the_edge_for_five_minutes" {
  command = plan

  assert {
    condition     = bunnynet_pullzone.site.cache_expiration_time == 300
    error_message = "The pull zone must keep files at the edge for five minutes."
  }
}

run "serves_stale_files_while_offline_or_updating" {
  command = plan

  assert {
    condition     = bunnynet_pullzone.site.cache_stale == toset(["offline", "updating"])
    error_message = "The pull zone must serve stale files while the storage zone is offline, and while it fetches new ones."
  }
}

run "accepts_only_modern_ciphers" {
  command = plan

  assert {
    condition     = bunnynet_pullzone.site.tls_level == "ModernOnly"
    error_message = "The pull zone must accept only TLS 1.2 or newer, with forward-secret key exchange and AEAD ciphers."
  }
}
