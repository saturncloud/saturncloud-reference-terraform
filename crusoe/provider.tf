terraform {
  required_providers {
    crusoe = {
      source = "crusoecloud/crusoe"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "crusoe" {
  # Configuration loaded from ~/.crusoe/config
}

provider "local" {
  # Local provider for managing local files
}