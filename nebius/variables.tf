variable "project_id" {
  description = "The parent ID for the Nebius cluster"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID for the Nebius cluster"
  type        = string
}

variable "viewers_group_id" {
  description = "The ID of the viewers group for Nebius Container Registry access"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}
