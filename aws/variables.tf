############################
# Account and naming
############################

variable "region" {
  description = "AWS region for every resource."
  type        = string
}

variable "org_name" {
  description = "Short name for this install. Lower-cased, and '_', ',', '.' and spaces become '-'. Names the cluster (saturn-cluster-<org_name>), the bucket (saturn-<org_name>) and the IAM roles, exactly as saturn-aws did."
  type        = string
}

variable "saturn_bucket_name" {
  description = "Name of the Saturn bucket created by ./bucket. Leave empty for saturn-<org_name>."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags added to every AWS resource, on top of saturn:org=<org_name> and app=Saturn."
  type        = map(string)
  default     = {}
}

############################
# Network
############################

variable "availability_zones" {
  description = "Exactly two availability zones. Leave empty for the first two zones of the region. Workers run in the first one."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) == 2
    error_message = "availability_zones must be empty or list exactly two zones."
  }
}

variable "vpc_cidr" {
  description = "CIDR of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs of the two public subnets, one per zone."
  type        = list(string)
  default     = ["10.0.64.0/19", "10.0.96.0/19"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs of the two private subnets, one per zone. Workers use the first."
  type        = list(string)
  default     = ["10.0.0.0/19", "10.0.32.0/19"]
}

variable "service_ipv4_cidr" {
  description = "Kubernetes service CIDR. Must be a /16 and must not overlap the VPC or the Calico pool."
  type        = string
  default     = "172.20.0.0/16"
}

variable "calico_ipv4_pool_cidr" {
  description = "Calico pod CIDR. Must not overlap the VPC or the service CIDR. Cannot be changed after install."
  type        = string
  default     = "192.168.0.0/16"
}

############################
# EKS control plane
############################

variable "kubernetes_version" {
  description = "EKS Kubernetes version. 1.32 is the saturn-aws 2026.02.01 default and the newest version its CoreDNS and add-on tables cover."
  type        = string
  default     = "1.32"
}

variable "cluster_accessibility" {
  description = "public-private (default): public and private API endpoints. public: public only. private: private only."
  type        = string
  default     = "public-private"

  validation {
    condition     = contains(["public", "public-private", "private"], var.cluster_accessibility)
    error_message = "cluster_accessibility must be public, public-private or private."
  }
}

variable "saturn_manager_cidrs" {
  description = "Saturn manager addresses allowed to reach the public API endpoint. Default is the production manager list from saturn-aws."
  type        = list(string)
  default     = ["18.218.90.60/32", "3.137.5.186/32", "3.139.188.227/32"]
}

variable "public_cluster_allow_list" {
  description = "Extra CIDRs allowed to reach the public API endpoint (saturn-aws public_cluster_allow_list). The machine running Terraform must be in it, or in the manager list, or reach the API privately."
  type        = list(string)
  default     = []
}

variable "k8s_api_allowed_cidrs" {
  description = "CIDRs allowed through the cluster security group on port 443 (private endpoint)."
  type        = list(string)
  default     = []
}

variable "k8s_api_allowed_security_group_ids" {
  description = "Security groups allowed through the cluster security group on port 443 (private endpoint)."
  type        = list(string)
  default     = []
}

variable "authentication_mode" {
  description = "EKS authentication mode. API is the saturn-aws default for new installs."
  type        = string
  default     = "API"

  validation {
    condition     = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be CONFIG_MAP, API or API_AND_CONFIG_MAP."
  }
}

variable "eks_secrets_kms_arn" {
  description = "KMS key for EKS secrets encryption. Leave empty to create one."
  type        = string
  default     = ""
}

############################
# Nodes
############################

variable "system_node" {
  description = "System node group. Defaults match saturn-aws's system_node."
  type = object({
    instance_type     = optional(string, "r5.large")
    min_size          = optional(number, 1)
    max_size          = optional(number, 100)
    desired_capacity  = optional(number, 1)
    max_pods          = optional(number, 100)
    enable_monitoring = optional(bool, false)
  })
  default = {}
}

variable "instance_sizes" {
  description = "Workspace node sizes. Each gets an on-demand and a spot_ node group and is offered in Atlas. Defaults are saturn-aws's medium and large; add more in the same shape."
  type = list(object({
    name                = string
    display_name        = string
    instance_type       = string
    spot_instance_types = list(string)
    cores               = number
    memory              = string
    gpu                 = optional(number, 0)
    accelerator         = optional(string, "")
    min_size            = optional(number, 0)
    max_size            = optional(number, 100)
    desired_capacity    = optional(number, 0)
    max_pods            = optional(number, 12)
    reserved_memory     = optional(string, "512Mi")
    enable_monitoring   = optional(bool, false)
  }))
  default = [
    {
      name                = "medium"
      display_name        = "Medium"
      instance_type       = "t3.medium"
      spot_instance_types = ["t3.medium", "t3.large", "t3a.large", "t3a.medium"]
      cores               = 2
      memory              = "4Gi"
    },
    {
      name                = "large"
      display_name        = "Large"
      instance_type       = "r5.large"
      spot_instance_types = ["r5.large", "r5d.large", "r5a.large", "r5ad.large", "r5n.large", "r5dn.large", "r4.large", "r3.large"]
      cores               = 2
      memory              = "16Gi"
    },
  ]
}

variable "default_cpu_size" {
  description = "Instance size Atlas offers by default. Must be one of instance_sizes."
  type        = string
  default     = "large"
}

variable "workers_additional_policies" {
  description = "Extra IAM policy ARNs attached to the worker role."
  type        = list(string)
  default     = []
}

############################
# Storage
############################

variable "network_filesystem_enabled" {
  description = "Create an EFS filesystem for Saturn's shared folders."
  type        = bool
  default     = false
}

variable "object_storage_enabled" {
  description = "Enable Saturn object storage (adds a lifecycle rule on the bucket)."
  type        = bool
  default     = false
}

variable "object_storage_upload_expiration_days" {
  description = "Days before incomplete uploads under saturnfs/ are aborted."
  type        = number
  default     = 1
}

############################
# Saturn
############################

variable "manage_helm" {
  description = "Install Calico and the Saturn operator from Terraform. With false, Terraform stops at an empty cluster and you install both by hand (README.md)."
  type        = bool
  default     = true
}

variable "calico_chart_path" {
  description = "Path to the calico chart taken from the operator image. Leave empty for .charts/calico next to this file, where scripts/fetch-calico-chart.sh puts it."
  type        = string
  default     = ""
}

variable "helm_chart_version" {
  description = "saturn-helm-operator chart version. Must be set: chart versions are pre-release style, so Helm cannot pick a latest."
  type        = string
  default     = null
}

variable "saturn_customer_name" {
  description = "Customer name the bootstrap token was issued for."
  type        = string
}

variable "saturn_admin_email" {
  description = "Email of the first Saturn admin."
  type        = string
}

variable "saturn_domain" {
  description = "Saturn domain. Leave empty for <saturn_customer_name>.saturnenterprise.io."
  type        = string
  default     = ""
}

variable "saturn_bootstrap_token" {
  description = "Saturn bootstrap token. Pass it with TF_VAR_saturn_bootstrap_token, never in a tfvars file."
  type        = string
  sensitive   = true
}

variable "saturn_manager_uri" {
  description = "Saturn manager the bootstrap token belongs to. saturn-aws installs use https://manager.aws.saturnenterprise.io."
  type        = string
  default     = "https://manager.aws.saturnenterprise.io"
}
