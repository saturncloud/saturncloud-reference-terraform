variable "cluster_name" {
  type        = string
  default     = "saturn-cluster"
  description = "Name of the GKE cluster that will be deployed in this VPC"
}

variable "project_id" {
  type        = string
  description = "project id"
}

variable "cidr" {
  type        = string
  description = "cidr block for the google compute subnetwork"
}

variable "region" {
  type        = string
  description = "region"
}

variable "zone" {
  type        = string
  description = "AZ"
}

variable "regional_cluster" {
  type        = bool
  default     = false
  description = "Whether to create a regional cluster (true) or zonal cluster (false)"
}
