# This file is named `.tofu` rather than `.tf` because some tools that read
# `.tf` files fail on a `language` block in a `.tf` file.

language {
  compatible_with {
    opentofu = ">= 1.12.0"
  }
}

terraform {
  required_providers {
    bunnynet = {
      source  = "BunnyWay/bunnynet"
      version = ">= 0.19.1, < 0.20.0"
    }
  }
}
