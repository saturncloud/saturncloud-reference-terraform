terraform {
  # saturn-aws runs Terraform 1.5.7. Its aws-auth null_resource refers to
  # itself, which 1.5.7 and 1.9.8 accept and 1.13 rejects as a cycle.
  required_version = ">= 1.5.7, < 1.10"

  # State lives in the Saturn bucket created by ./bucket, at the key layout
  # saturn-aws used (terraform/<org_name>/...). Supply bucket, key and region
  # with -backend-config (see README.md). No state locking, as in saturn-aws.
  backend "s3" {}

  # The pins saturn-aws release-2026.02.01 uses (templates/terraform/local-providers/versions.tf).
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.72.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.1.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}
