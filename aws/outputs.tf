output "cluster_name" {
  description = "EKS cluster name."
  value       = local.cluster_name
}

output "kubeconfig_command" {
  description = "Writes a kubeconfig for the cluster."
  value       = "aws eks update-kubeconfig --name ${local.cluster_name} --region ${var.region}"
}

output "saturn_url" {
  description = "Saturn web address."
  value       = "https://app.${local.saturn_domain}"
}

output "acm_certificate_arn" {
  value = local.acm_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.vpc_public_subnets
}

output "private_subnet_ids" {
  value = module.vpc.vpc_private_subnets
}

output "nat_gateway_ips" {
  value = module.vpc.vpc_nat_gateway_ips
}

output "worker_security_group_id" {
  value = module.cluster.worker_security_group_id
}

output "oidc_provider_arn" {
  value = module.cluster.oidc_provider_arn
}

output "atlas_role_arn" {
  value = module.cluster.atlas_role_arn
}

output "ebs_csi_role_arn" {
  value = module.cluster.ebs_csi_role_arn
}

output "saturn_nfs_efs_id" {
  value = module.cluster.saturn_nfs_efs_id
}
