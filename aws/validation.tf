# The same checks saturn-aws makes in aws_config.py before it writes tfvars.
locals {
  cidrs_overlap = {
    for pair in [
      ["vpc_cidr", var.vpc_cidr, "service_ipv4_cidr", var.service_ipv4_cidr],
      ["vpc_cidr", var.vpc_cidr, "calico_ipv4_pool_cidr", var.calico_ipv4_pool_cidr],
      ["service_ipv4_cidr", var.service_ipv4_cidr, "calico_ipv4_pool_cidr", var.calico_ipv4_pool_cidr],
      ] : "${pair[0]}/${pair[2]}" => (
      # Two CIDRs overlap when the shorter prefix contains the other's base address.
      cidrsubnet("${cidrhost(pair[1], 0)}/${min(split("/", pair[1])[1], split("/", pair[3])[1])}", 0, 0) ==
      cidrsubnet("${cidrhost(pair[3], 0)}/${min(split("/", pair[1])[1], split("/", pair[3])[1])}", 0, 0)
    )
  }
}

resource "terraform_data" "validate" {
  lifecycle {
    precondition {
      condition     = split("/", var.service_ipv4_cidr)[1] == "16"
      error_message = "service_ipv4_cidr must be a /16."
    }
    precondition {
      condition     = !anytrue(values(local.cidrs_overlap))
      error_message = "vpc_cidr, service_ipv4_cidr and calico_ipv4_pool_cidr must not overlap: ${jsonencode(local.cidrs_overlap)}"
    }
    precondition {
      condition     = contains([for s in local.requested_sizes : s.name], var.default_cpu_size)
      error_message = "default_cpu_size must be the name of one of instance_sizes."
    }
    precondition {
      condition     = !var.manage_helm || var.helm_chart_version != null
      error_message = "helm_chart_version must be set when manage_helm is true."
    }
  }
}
