terraform {
  # use_lockfile (S3-native state locking) needs Terraform 1.10 or newer.
  required_version = ">= 1.10"

  # State lives in the Saturn bucket created by ./bucket, at the same key
  # layout saturn-aws used: terraform/<org_name>/cluster.tfstate.
  # Supply bucket, key and region with -backend-config (see README.md).
  backend "s3" {
    use_lockfile = true
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Same pin as saturn-aws release-2026.02.01.
      version = "= 5.72.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}
