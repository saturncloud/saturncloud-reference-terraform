variable "cluster_name" {
  type = string
  default = "saturn-cluster"
  description = "Name of the EKS cluster that will be deployed in this VPC"
}

variable "vpc_cidr" {
  type = string
  description = "CIDR of the VPC"
}

variable "vpc_public_subnets" {
  type = list(string)
  default = [
    "10.0.64.0/19", "10.0.96.0/19"
  ]
  description = "CIDRs of the public subnets for the VPC"
}

variable "vpc_private_subnets" {
  type = list(string)
  default = [
    "10.0.0.0/19", "10.0.32.0/19"
  ]
  description = "CIDRs of the private subnets for the VPC"
}

variable "vpc_azs" {
  type = list(string)
  description = "Availability zones where private and public subnets will be created"
}

variable "create_vpc" {
  type = bool
  default = true
  description = "If set to false, VPC will not be created"
}
