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

run "names_both_zones_after_the_zone_name" {
  command = plan

  assert {
    condition     = bunnynet_storage_zone.site.name == "example-site"
    error_message = "The storage zone must be named by `zone_name`."
  }

  assert {
    condition     = bunnynet_pullzone.site.name == "example-site"
    error_message = "The pull zone must be named by `zone_name`."
  }
}

run "accepts_a_zone_name_of_4_characters" {
  command = plan

  variables {
    zone_name = "abcd"
  }

  assert {
    condition     = bunnynet_storage_zone.site.name == "abcd"
    error_message = "The zone name rule must allow 4 characters."
  }
}

run "accepts_a_zone_name_of_63_characters" {
  command = plan

  variables {
    zone_name = "012345678901234567890123456789012345678901234567890123456789012"
  }

  assert {
    condition     = length(bunnynet_pullzone.site.name) == 63
    error_message = "The zone name rule must allow 63 characters."
  }
}

run "rejects_a_zone_name_shorter_than_4_characters" {
  command = plan

  expect_failures = [var.zone_name]

  variables {
    zone_name = "abc"
  }
}

run "rejects_a_zone_name_longer_than_63_characters" {
  command = plan

  expect_failures = [var.zone_name]

  variables {
    zone_name = "0123456789012345678901234567890123456789012345678901234567890123"
  }
}

run "rejects_a_zone_name_with_capitals" {
  command = plan

  expect_failures = [var.zone_name]

  variables {
    zone_name = "Example-site"
  }
}

run "rejects_a_zone_name_with_dots" {
  command = plan

  expect_failures = [var.zone_name]

  variables {
    zone_name = "example.site"
  }
}

run "rejects_a_zone_name_starting_with_a_hyphen" {
  command = plan

  expect_failures = [var.zone_name]

  variables {
    zone_name = "-example-site"
  }
}

run "rejects_a_zone_name_ending_with_a_hyphen" {
  command = plan

  expect_failures = [var.zone_name]

  variables {
    zone_name = "example-site-"
  }
}
