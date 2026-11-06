provider "aws" {
  region = var.region

  # Saturn's own production account. saturn-aws refuses to run against it; so does this.
  forbidden_account_ids = ["227979560085"]

  default_tags {
    tags = local.tags
  }
}

# The Kubernetes and Helm providers authenticate as whoever runs Terraform,
# through `aws eks get-token`. With authentication_mode = "API" that identity
# is the cluster creator, which EKS makes a cluster admin.
locals {
  kube_exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name, "--region", var.region]
  }
}

provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  exec {
    api_version = local.kube_exec.api_version
    command     = local.kube_exec.command
    args        = local.kube_exec.args
  }
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    exec                   = local.kube_exec
  }
}
