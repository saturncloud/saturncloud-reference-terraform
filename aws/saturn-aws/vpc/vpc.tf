# VPC with 2 pub and 2 priv subnets into supplied AZs with NAT gateway

locals {
  vpc_name = "${var.cluster_name}-vpc"
}

module "vpc" {
  source  = "./modules/terraform-aws-vpc"

  create_vpc = var.create_vpc

  name    = local.vpc_name
  cidr    = var.vpc_cidr

  azs     = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets
  map_public_ip_on_launch = true
  enable_nat_gateway = true
  single_nat_gateway = true
  one_nat_gateway_per_az = false

  # Default security group - ingress/egress rules cleared to work like "deny all"
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_dns_hostnames = true

  tags = {
    Name = local.vpc_name
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}
