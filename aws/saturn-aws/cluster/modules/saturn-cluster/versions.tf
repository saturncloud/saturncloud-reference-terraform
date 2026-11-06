terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.72.0"
    }

    template = {
      source = "hashicorp/template"
      version = "2.2.0"
    }

    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }

    local = {
      source = "hashicorp/local"
      version = "2.1.0"
    }

    null = {
      source = "hashicorp/null"
      version = "3.1.0"
    }

  }
  required_version = ">= 0.13"
}
