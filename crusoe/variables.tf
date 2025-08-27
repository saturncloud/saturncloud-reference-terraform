variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "saturn-cluster-crusoe"
}

variable "ssh_key_path" {
  description = "Path to SSH public key for accessing nodes"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "project_id" {
  description = "Crusoe project ID"
  type        = string
}

variable "location" {
  description = "Crusoe location for cluster deployment"
  type        = string
  default     = "us-east1-a"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster (must be in format MAJOR.MINOR.BUGFIX-cmk.NUM)"
  type        = string
  default     = "1.30.8-cmk.28"
}

# Cluster Add-ons
variable "cluster_addons" {
  description = "List of add-ons to enable on the cluster (cluster_autoscaler, nvidia_gpu_operator, nvidia_network_operator, crusoe_csi)"
  type        = list(string)
  default = [
    "cluster_autoscaler",
    "nvidia_gpu_operator",
    "nvidia_network_operator",
    "crusoe_csi"
  ]
}

# System Node Pool Configuration
variable "system_node_type" {
  description = "Instance type for system nodes"
  type        = string
  default     = "c1a.4x"
}