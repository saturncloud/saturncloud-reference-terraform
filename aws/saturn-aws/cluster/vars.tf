variable cluster_name {
  type = string
  default = "saturn-cluster"
  description = "Name of the EKS cluster"
}

variable org_name {
  type = string
  description = "Name of the organization that owns the cluster"
}

variable cluster_version {
  type = string
  description = "Kubernetes cluster version"
}

variable account_id {
  type = string
  description = "AWS Account ID"
}

variable vpc_id {
  type = string
  description = "VPC ID where the cluster will be deployed"
}

variable vpc_cidr {
  type = string
  description = "VPC CIDR block"
}

variable public_subnet_ids {
  type = list
  default = []
  description = "List of public subnet IDs used by the cluster for NAT and Loadbalancers"
}

variable private_subnet_ids {
  type = list
  default = []
  description = "List of private subnet IDs used for creating workers"
}

variable worker_subnet_ids {
  type = list
  description = "List of subnet IDs where workers will be created"
}

variable allow_public_endpoint {
  type = bool
  default = true
  description = "If enabled, the EKS control plane can be connected to from the public internet"
}

variable allow_private_endpoint {
  type = bool
  default = false
  description = "If enabled, cluster nodes will connect to the control plane via private (internal) endpoints"
}

variable public_endpoint_cidrs {
  type = list
  default = []
  description = "List of CIDRs that will be allowed to access the control plane over the public internet"
}

variable k8s_api_allowed_security_group_ids {
  type = list
  default = []
  description = "Additional security groups allowed to access the kubernetes API"
}

variable k8s_api_allowed_cidrs {
  type = list
  default = []
  description = "Additional CIDRs allowed to access the kubernetes API"
}

variable tags {
  type = map
  default = {}
  description = "Tags to add to every resource"
}

variable saturn_bucket_name {
  type = string
  description = "Name of the S3 bucket used by Saturn"
}

variable service_ipv4_cidr {
  type = string
  description = "Configuration for kubernetes ipv4 cidr block"
}

locals {
  map_roles = [
    {
      rolearn  = "arn:aws:iam::${var.account_id}:role/customer-admin-self-managed",
      username = "customer-admin-self-managed",
      groups   = ["system:masters"]
    },
    {
      rolearn  = "${local.atlas_role_arn}",
      username = "saturn-ui",
      groups   = ["system:masters"]
    }
  ]
}

variable iam_user_policy {
  type = string
  default = ""
  description = "Optional override for the default IAM user policy"
}


variable cpu_ami {
  type = string
  default = ""
  description = "AMI for CPU instances"
}

variable gpu_ami {
  type = string
  description = "AMI for GPU instances"
}

variable system_asg_config {
  type = object({
    name                = string
    instance_type       = string
    cores               = number
    memory              = string
    gpu                 = optional(number, 0)
    accelerator         = optional(string, "")
    min_size            = optional(number, 0)
    max_size            = optional(number, 100)
    desired_capacity    = optional(number, 0)
    max_pods            = optional(number, 100)
    spot_instance_types = optional(list(string), [])
    enable_monitoring   = optional(bool, true)
  })
  description = "configuration for system nodes"
}

variable asg_config {
  type = list(object({
    name                = string
    instance_type       = string
    cores               = number
    memory              = string
    gpu                 = optional(number, 0)
    accelerator         = optional(string, "")
    min_size            = optional(number, 0)
    max_size            = optional(number, 100)
    desired_capacity    = optional(number, 0)
    max_pods            = optional(number, 12)
    spot_instance_types = optional(list(string), [])
    enable_monitoring   = optional(bool, true)
  }))
  description = "configuration for nodes"
}

variable "workers_additional_policies" {
  description = "Additional policies to be added to workers"
  type        = list(string)
  default     = []
}

variable "manage_cluster_iam_resources" {
  description = "Whether to manage IAM resources for EKS clusters. Passed through to terraform-aws-eks"
  type = bool
  default = true
}

variable "manage_worker_iam_resources" {
  description = "Whether to manage IAM resources for EKS workers. Passed through to terraform-aws-eks"
  type = bool
  default = true
}

variable "workers_group_defaults" {
  description = "defaults for EKS workers. Passed through to terraform-aws-eks"
  type = map
  default = {}
}

variable "cluster_iam_role_name" {
  description = "iam_role for EKS cluster. Passed through to terraform-aws-eks"
  type = string
  default = ""
}

variable "manage_saturn_iam_resources" {
  description = "Whether to create the IAM user for Atlas."
  type = bool
  default = true
}

variable "eks_oidc_root_ca_thumbprint" {
  type        = string
  description = "Thumbprint of Root CA for EKS OIDC, Valid until 2037"
  default     = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
}

variable "openid_connect_audiences" {
  description = "List of OpenID Connect audience client IDs to add to the IRSA provider."
  type        = list(string)
  default     = []
}

locals {
  sts_principal            = "sts.amazonaws.com"
  client_id_list           = distinct(compact(concat([local.sts_principal], var.openid_connect_audiences)))
  cluster_oidc_issuer_url  = module.saturn-cluster.cluster_oidc_issuer_url
  oidc_provider_id         = trimprefix(local.cluster_oidc_issuer_url, "https://")
  oidc_provider_arn        = concat(aws_iam_openid_connect_provider.oidc_provider[*].arn, [""])[0]
  worker_security_group_id = module.saturn-cluster.worker_security_group_id
  ebs_csi_role_arn         = var.manage_ebs_iam_resources ? aws_iam_role.ebs_csi[0].arn : var.ebs_iam_role_arn
  atlas_role_arn           = var.manage_saturn_iam_resources ? aws_iam_role.atlas[0].arn : var.atlas_role_arn
}

variable nfs_iam_role_policy {
  type = string
  default = ""
  description = "Optional override for the default IAM role policy"
}

variable "manage_nfs_iam_resources" {
  description = "Whether to create the IAM user for network filesystems."
  type = bool
  default = false
}

variable "manage_efs" {
  description = "Whether to create an EFS installation"
  type = bool
  default = false
}

variable region{
  type = string
  description = "AWS Region"
}

variable worker_zone{
  type = string
  description = "AWS Zone where workers are provisioned"
}

variable eks_secrets_kms_arn{
  type = string
  description = "the arn to use for encrypting eks secrets, if not provided, we will attempt to create one"
  default = ""
}

variable manage_ebs_iam_resources {
  type = bool
  description = "whether or not to create the IAM role for the EBS CSI driver"
  default = false
}

variable ebs_iam_role_arn {
  type = string
  description = "IAM role arn for the EBS csi driver. Must be set if manage_ebs_iam_resources is false"
  default = ""
}

variable atlas_role_arn {
  type = string
  description = "IAM role for the Atlas UI"
  default = ""
}

variable object_storage_enabled {
  type = bool
  description = "True is saturnfs object storage is enabled on the cluster"
  default = false
}

variable object_storage_upload_expiration_days {
  type = number
  description = "Expire saturnfs incomplete object storage uploads older than X days"
  default = 1
}

variable authentication_mode {
  description = "EKS cluster authentication mode. Valid values are CONFIG_MAP, API, or API_AND_CONFIG_MAP"
  type        = string
  default     = "CONFIG_MAP"
  validation {
    condition = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.authentication_mode)
    error_message = "Authentication mode must be CONFIG_MAP, API, or API_AND_CONFIG_MAP."
  }
}

variable access_entries_principal_arns {
  description = "List of principal ARNs to create access entries for when using API authentication mode. Each entry will be granted system:masters permissions."
  type        = list(string)
  default     = []
}
