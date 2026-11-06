# The Saturn bucket (saturn-<org_name>), created first because it also holds
# the main stack's Terraform state. Settings are the ones saturn-aws applies
# with boto3 in create_bucket: private ACL, all public access blocked,
# AES256 default encryption. This stack keeps its own state locally; it has
# only these few resources and is destroyed last.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.72.0"
    }
  }
}

variable "region" {
  type = string
}

variable "org_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "force_destroy" {
  description = "Let terraform destroy delete the bucket with objects (state, logs) still in it."
  type        = bool
  default     = false
}

provider "aws" {
  region                = var.region
  forbidden_account_ids = ["227979560085"]
}

locals {
  org_name = lower(replace(var.org_name, "/[_,. ]/", "-"))
  tags = merge(var.tags, {
    Name         = "saturn-${local.org_name}"
    app          = "saturn"
    "saturn:org" = local.org_name
  })
}

resource "aws_s3_bucket" "saturn" {
  bucket        = "saturn-${local.org_name}"
  force_destroy = var.force_destroy
  tags          = local.tags
}

# No ownership controls or ACL resource: a new bucket defaults to
# BucketOwnerEnforced with the private ACL, which is what saturn-aws's
# create_bucket(ACL="private") produces.

resource "aws_s3_bucket_public_access_block" "saturn" {
  bucket                  = aws_s3_bucket.saturn.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "saturn" {
  bucket = aws_s3_bucket.saturn.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

output "bucket_name" {
  value = aws_s3_bucket.saturn.id
}
