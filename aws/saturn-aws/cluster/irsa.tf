resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = local.client_id_list
  thumbprint_list = [var.eks_oidc_root_ca_thumbprint]
  url             = local.cluster_oidc_issuer_url
}

# resource "aws_eks_identity_provider_config" "saturn_cluster_oidc" {
#   cluster_name = var.cluster_name
#
#   oidc {
#     client_id                     = "sts.amazonaws.com"
#     identity_provider_config_name = var.cluster_name
#     issuer_url                    = local.cluster_oidc_issuer_url
#   }
#
#   tags = var.tags
# }
