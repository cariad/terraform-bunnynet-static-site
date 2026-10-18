# Holds the website's files.
resource "bunnynet_storage_zone" "site" {
  custom_404_file_path = "/404.html"
  name                 = var.zone_name
  region               = "DE" # The "Edge" tier requires Germany

  # This highly-opinionated module replicates the site into all (as of
  # 2026-10-17) edge regions for the lowest latency.
  #
  # Yes, this increases the cost — but for a regular little indie website, 15 ×
  # pennies is still pennies.
  replication_regions = [
    "BR",
    "CZ",
    "ES",
    "HK",
    "JH",
    "JP",
    "LA",
    "MI",
    "NY",
    "SE",
    "SG",
    "SYD",
    "UK",
    "WA"
  ]

  # SSD storage, versus spinning platters.
  #
  # A little bit more expensive, but: Edge drives respond in 1-5 ms rather than
  # the Standard tier's 30-300 ms. The pull zone keeps most files for only five
  # minutes, so it fetches from storage often — and 300 ms is too darned slow.
  zone_tier = "Edge"
}
