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

run "stores_files_in_germany" {
  command = plan

  assert {
    condition     = bunnynet_storage_zone.site.region == "DE"
    error_message = "The storage zone's main region must be `DE`, the Edge tier's only one."
  }
}

run "replicates_files_to_every_other_edge_region" {
  command = plan

  assert {
    condition     = bunnynet_storage_zone.site.replication_regions == toset(["BR", "CZ", "ES", "HK", "JH", "JP", "LA", "MI", "NY", "SE", "SG", "SYD", "UK", "WA"])
    error_message = "The storage zone must replicate its files to every other Edge region."
  }
}

run "serves_the_websites_own_404_page" {
  command = plan

  assert {
    condition     = bunnynet_storage_zone.site.custom_404_file_path == "/404.html"
    error_message = "The storage zone must serve `/404.html` for missing files."
  }
}

run "uses_the_edge_tier" {
  command = plan

  assert {
    condition     = bunnynet_storage_zone.site.zone_tier == "Edge"
    error_message = "The storage zone must use the Edge tier."
  }
}
