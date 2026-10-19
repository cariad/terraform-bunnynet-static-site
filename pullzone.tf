# Serves the storage zone's files through bunny.net's CDN.
resource "bunnynet_pullzone" "site" {
  # Keep files at the edge for five minutes, unless an edge rule (e.g.
  # `year_long_files.tf`) says otherwise.
  cache_expiration_time = 300

  # Don't cache in the browser, unless an edge rule (e.g. `year_long_files.tf`)
  # says otherwise.
  cache_expiration_time_browser = 0

  # - `offline`: serve cached files when the storage zone is unreachable.
  # - `updating`: serve cached files while the edge updates in the background.
  cache_stale = ["offline", "updating"]

  name      = var.zone_name
  tls_level = "ModernOnly"

  origin {
    storagezone = bunnynet_storage_zone.site.id
    type        = "StorageZone"
  }

  routing {}
}
