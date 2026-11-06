resource "aws_kms_key" "eks_secrets" {
  count = var.eks_secrets_kms_arn == "" ? 1 : 0
  description = "kms key used to encrypt secrets in EKS for Saturn Cloud"
}
