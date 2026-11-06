output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "kubeconfig_command" {
  description = "Writes a kubeconfig for the cluster."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${var.region}"
}

output "saturn_url" {
  description = "Saturn web address."
  value       = local.saturn_base_url
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_gateway_ips" {
  value = aws_eip.nat[*].public_ip
}

output "worker_security_group_id" {
  value = aws_security_group.workers.id
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.oidc_provider.arn
}

output "atlas_role_arn" {
  value = aws_iam_role.atlas.arn
}

output "ebs_csi_role_arn" {
  value = aws_iam_role.ebs_csi.arn
}

output "saturn_nfs_efs_id" {
  value = var.network_filesystem_enabled ? aws_efs_file_system.saturn_nfs_efs[0].id : ""
}
