# EKS control plane. Settings follow saturn-aws's saturn-cluster module.

resource "aws_kms_key" "eks_secrets" {
  count       = var.eks_secrets_kms_arn == "" ? 1 : 0
  description = "kms key used to encrypt secrets in EKS for Saturn Cloud"
}

resource "aws_iam_role" "cluster" {
  name_prefix           = local.cluster_name
  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role.json
  force_detach_policies = true
}

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    sid     = "EKSClusterAssumeRole"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_security_group" "cluster" {
  name_prefix = local.cluster_name
  description = "EKS cluster security group."
  vpc_id      = aws_vpc.this.id
  tags = {
    Name = "${local.cluster_name}-eks_cluster_sg"
  }
}

resource "aws_security_group_rule" "cluster_egress_internet" {
  description       = "Allow cluster egress access to the Internet."
  protocol          = "-1"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "cluster_https_worker_ingress" {
  description              = "Allow pods to communicate with the EKS cluster API."
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.workers.id
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "k8s_api_cidrs" {
  count             = length(var.k8s_api_allowed_cidrs) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.k8s_api_allowed_cidrs
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "k8s_api_security_groups" {
  for_each                 = toset(var.k8s_api_allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = each.key
  security_group_id        = aws_security_group.cluster.id
}

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  # saturn-aws let EKS install the AWS VPC CNI, kube-proxy and CoreDNS, then
  # deleted the CNI before any node joined. Not installing them reaches the
  # same state in one step: kube-proxy comes back as an add-on below, CoreDNS
  # comes from the Saturn operator, Calico from k8s.tf.
  bootstrap_self_managed_addons = false

  kubernetes_network_config {
    service_ipv4_cidr = var.service_ipv4_cidr
  }

  vpc_config {
    security_group_ids      = [aws_security_group.cluster.id]
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = local.allow_private_endpoint
    endpoint_public_access  = local.allow_public_endpoint
    public_access_cidrs     = local.public_endpoint_cidrs
  }

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    provider {
      key_arn = var.eks_secrets_kms_arn != "" ? var.eks_secrets_kms_arn : aws_kms_key.eks_secrets[0].arn
    }
    resources = ["secrets"]
  }

  timeouts {
    create = "25m"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy,
    terraform_data.validate,
  ]
}

# Lets the worker role join the cluster in API and API_AND_CONFIG_MAP modes.
resource "aws_eks_access_entry" "workers" {
  count         = var.authentication_mode != "CONFIG_MAP" ? 1 : 0
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.workers.arn
  type          = "EC2_LINUX"
}

# IRSA. Same thumbprint and audience as saturn-aws.
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

locals {
  oidc_provider_id  = trimprefix(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://")
  oidc_provider_arn = aws_iam_openid_connect_provider.oidc_provider.arn

  # Add-on versions saturn-aws 2026.02.01 installs for Kubernetes 1.32
  # (aws_installation.py ebs_csi_version / kube_proxy_version).
  addon_versions = {
    "1.32" = { kube_proxy = "v1.32.11-eksbuild.5", ebs_csi = "v1.56.0-eksbuild.1" }
  }
}

# saturn-aws created these with boto3 after Terraform; same versions and settings.
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  addon_version               = local.addon_versions[var.kubernetes_version].kube_proxy
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = local.addon_versions[var.kubernetes_version].ebs_csi
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  configuration_values        = file("${path.module}/templates/csi_config.json")
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # The controller runs on system nodes, which need Calico first.
  depends_on = [aws_autoscaling_group.workers, helm_release.calico]
}
