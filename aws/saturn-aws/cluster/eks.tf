# Kubernetes on AWS (EKS)

module "saturn-cluster" {
  source          = "./modules/saturn-cluster"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = var.vpc_id
  subnets         = concat(var.public_subnet_ids, var.private_subnet_ids)

  worker_groups_launch_template = local.worker_groups_launch_template
  map_roles                     = local.map_roles
  cluster_create_timeout        = "25m"

  cluster_endpoint_private_access = var.allow_private_endpoint
  cluster_endpoint_public_access  = var.allow_public_endpoint
  cluster_endpoint_public_access_cidrs = var.public_endpoint_cidrs
  service_ipv4_cidr = var.service_ipv4_cidr

  manage_cluster_iam_resources     = var.manage_cluster_iam_resources
  cluster_iam_role_name            = var.cluster_iam_role_name
  manage_worker_iam_resources      = var.manage_worker_iam_resources
  manage_worker_autoscaling_policy = true # this is unused if manage_worker_iam_resources is fals
  workers_group_defaults           = var.workers_group_defaults
  workers_additional_policies      = var.workers_additional_policies

  tags = var.tags
  eks_secrets_kms_arn              = var.eks_secrets_kms_arn != "" ? var.eks_secrets_kms_arn : aws_kms_key.eks_secrets[0].arn
  
  authentication_mode          = var.authentication_mode
  access_entries_principal_arns = var.access_entries_principal_arns
}

data "aws_eks_cluster" "cluster" {
  name = module.saturn-cluster.cluster_id
}
