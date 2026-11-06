output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider."
  value       = concat(aws_iam_openid_connect_provider.oidc_provider[*].arn, [""])[0]
}

output "worker_security_group_id" {
  description = "Security group ID attached to the EKS workers."
  value       = local.worker_security_group_id
}

output "saturn_nfs_efs_id" {
  description = "AWS EFS filesystem ID for the organization."
  value       = join("", aws_efs_file_system.saturn_nfs_efs[*].id)
}

output "ebs_csi_role_arn" {
  description = "the ARN of the iam role for the ebs csi driver"
  value = local.ebs_csi_role_arn
}

output "atlas_role_arn" {
  description = "the ARN of the IAM role for atlas"
  value = local.atlas_role_arn
}
