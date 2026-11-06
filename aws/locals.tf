locals {
  # saturn-aws normalises the org name the same way before naming anything.
  org_name           = lower(replace(var.org_name, "/[_,. ]/", "-"))
  cluster_name       = "saturn-cluster-${local.org_name}"
  vpc_name           = "${local.cluster_name}-vpc"
  saturn_bucket_name = var.saturn_bucket_name != "" ? var.saturn_bucket_name : "saturn-${local.org_name}"

  tags = merge(var.tags, {
    "saturn:org" = local.org_name
    app          = "Saturn"
  })

  azs         = length(var.availability_zones) > 0 ? var.availability_zones : slice(sort(data.aws_availability_zones.available.names), 0, 2)
  worker_zone = local.azs[0]

  allow_public_endpoint  = var.cluster_accessibility != "private"
  allow_private_endpoint = var.cluster_accessibility != "public"
  public_endpoint_cidrs = local.allow_public_endpoint ? distinct(concat(
    var.saturn_manager_cidrs,
    [for ip in aws_eip.nat[*].public_ip : "${ip}/32"],
    var.public_cluster_allow_list,
  )) : null

  dns_service_ip = cidrhost(var.service_ipv4_cidr, 10)
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
