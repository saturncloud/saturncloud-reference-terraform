provider "aws" {
  region = var.region

  # Saturn's own production account. saturn-aws refuses to run against it; so does this.
  forbidden_account_ids = ["227979560085"]

  # Added for this module: one tag on everything, so an install's resources
  # can be found and removed. The saturn-aws stacks still apply var.tags themselves.
  default_tags {
    tags = merge(var.tags, { "saturn:org" = local.org_name })
  }
}

# Only used once the nodes are up (start_nodes = true), when the cluster exists.
data "aws_eks_cluster" "this" {
  count = var.start_nodes ? 1 : 0
  name  = local.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = try(data.aws_eks_cluster.this[0].endpoint, "")
    cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data), "")
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", var.region]
    }
  }
}
