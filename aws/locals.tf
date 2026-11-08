locals {
  # saturn-aws normalises the org name the same way before naming anything.
  org_name           = lower(replace(var.org_name, "/[_,. ]/", "-"))
  cluster_name       = "saturn-cluster-${local.org_name}"
  saturn_bucket_name = "saturn-${local.org_name}"

  saturn_domain = var.saturn_domain != "" ? var.saturn_domain : "${var.saturn_customer_name}.saturnenterprise.io"

  azs         = length(var.availability_zones) > 0 ? var.availability_zones : slice(sort(data.aws_availability_zones.available.names), 0, 2)
  worker_zone = local.azs[0]

  # aws_config.py public_endpoint_cidr_list: manager addresses, the NAT
  # gateway's address and the install's own allow list.
  allow_public_endpoint  = var.cluster_accessibility != "private"
  allow_private_endpoint = var.cluster_accessibility != "public"
  public_endpoint_cidrs = local.allow_public_endpoint ? concat(
    var.saturn_manager_cidrs,
    [for ip in module.vpc.vpc_nat_gateway_ips : "${ip}/32"],
    var.public_cluster_allow_list,
  ) : []

  dns_service_ip = cidrhost(var.service_ipv4_cidr, 10)
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}
