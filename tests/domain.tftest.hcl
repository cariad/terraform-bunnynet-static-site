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

run "accepts_a_subdomain" {
  command = plan

  variables {
    domain = "blog.example.com"
  }

  assert {
    condition     = bunnynet_pullzone_hostname.bare.name == "blog.example.com"
    error_message = "The bare hostname must be the domain."
  }
}

run "accepts_a_domain_of_249_characters" {
  command = plan

  variables {
    domain = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc.ddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
  }

  assert {
    condition     = length(bunnynet_pullzone_hostname.bare.name) == 249
    error_message = "The domain rule must allow 249 characters, so that `www.` fits within 253."
  }
}

run "accepts_a_label_of_63_characters" {
  command = plan

  variables {
    domain = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.com"
  }

  assert {
    condition     = bunnynet_pullzone_hostname.bare.name == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.com"
    error_message = "The domain rule must allow labels of 63 characters."
  }
}

run "accepts_labels_of_1_character" {
  command = plan

  variables {
    domain = "a.b"
  }

  assert {
    condition     = bunnynet_pullzone_hostname.bare.name == "a.b"
    error_message = "The domain rule must allow labels of 1 character."
  }
}

run "accepts_a_punycode_domain" {
  command = plan

  variables {
    domain = "xn--80aswg.xn--p1ai"
  }

  assert {
    condition     = bunnynet_pullzone_hostname.bare.name == "xn--80aswg.xn--p1ai"
    error_message = "The domain rule must allow digits and hyphens inside a label."
  }
}

# The last label has its own copy of the label rule, so it has its own runs.
run "accepts_a_last_label_of_63_characters" {
  command = plan

  variables {
    domain = "example.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  assert {
    condition     = bunnynet_pullzone_hostname.bare.name == "example.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    error_message = "The domain rule must allow a last label of 63 characters."
  }
}

run "rejects_a_domain_longer_than_249_characters" {
  command = plan

  expect_failures = [var.domain]

  # Every label is valid, so only the length breaks the rule.
  variables {
    domain = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc.dddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
  }
}

run "rejects_a_label_longer_than_63_characters" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.com"
  }
}

run "rejects_a_last_label_longer_than_63_characters" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "example.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
}

# The module adds `www.` itself.
run "rejects_a_www_prefix" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "www.example.com"
  }
}

run "rejects_an_empty_label" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "example..com"
  }
}

run "rejects_a_single_label" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "localhost"
  }
}

run "rejects_an_empty_domain" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = ""
  }
}

run "rejects_an_uppercase_domain" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "Example.com"
  }
}

run "rejects_an_uppercase_last_label" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "example.COM"
  }
}

run "rejects_a_domain_with_an_underscore" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "my_site.example.com"
  }
}

run "rejects_a_label_starting_with_a_hyphen" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "-example.com"
  }
}

run "rejects_a_label_ending_with_a_hyphen" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "example-.com"
  }
}

run "rejects_a_last_label_starting_with_a_hyphen" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "example.-com"
  }
}

run "rejects_a_last_label_ending_with_a_hyphen" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "example.com-"
  }
}

run "rejects_a_trailing_dot" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "example.com."
  }
}

run "rejects_a_scheme" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "https://example.com"
  }
}

run "rejects_a_port" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "example.com:443"
  }
}

run "rejects_a_path" {
  command = plan

  expect_failures = [var.domain]

  variables {
    domain = "example.com/blog"
  }
}
