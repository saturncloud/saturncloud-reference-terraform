# saturn-aws's three Terraform stacks, used unchanged from
# saturn-aws release-2026.02.01 (commit 12bb7bd) under ./saturn-aws. Each
# argument below is a value saturn-aws's Python templated into that stack's
# terraform.tfvars (aws_installation.py _acm_template_vars,
# _vpc_template_vars, _cluster_template_vars).

module "acm" {
  source = "./saturn-aws/acm"

  domain = "*.${local.saturn_domain}"
  tags   = var.tags
}

module "vpc" {
  source = "./saturn-aws/vpc"

  cluster_name        = local.cluster_name
  vpc_cidr            = var.vpc_cidr
  vpc_public_subnets  = var.public_subnet_cidrs
  vpc_private_subnets = var.private_subnet_cidrs
  vpc_azs             = local.azs
  create_vpc          = true
}

module "cluster" {
  source = "./saturn-aws/cluster"

  account_id         = data.aws_caller_identity.current.account_id
  org_name           = local.org_name
  cluster_name       = local.cluster_name
  cluster_version    = var.kubernetes_version
  region             = var.region
  worker_zone        = local.worker_zone
  saturn_bucket_name = local.saturn_bucket_name
  tags               = var.tags

  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = var.vpc_cidr
  public_subnet_ids  = module.vpc.vpc_public_subnets
  private_subnet_ids = module.vpc.vpc_private_subnets
  # saturn-aws puts every node group in the first private subnet.
  worker_subnet_ids = slice(module.vpc.vpc_private_subnets, 0, 1)
  service_ipv4_cidr = var.service_ipv4_cidr

  allow_public_endpoint              = local.allow_public_endpoint
  allow_private_endpoint             = local.allow_private_endpoint
  public_endpoint_cidrs              = local.public_endpoint_cidrs
  k8s_api_allowed_security_group_ids = var.k8s_api_allowed_security_group_ids
  k8s_api_allowed_cidrs              = var.k8s_api_allowed_cidrs

  authentication_mode = var.authentication_mode
  # aws_config.py defaults this to the installing role. The cluster stack
  # declares it but no resource reads it; kept for parity.
  access_entries_principal_arns = [data.aws_iam_session_context.current.issuer_arn]
  eks_secrets_kms_arn           = var.eks_secrets_kms_arn

  # Empty: the stack picks the EKS-optimized AL2023 AMIs from SSM.
  cpu_ami = ""
  gpu_ami = ""

  # The first apply creates the system group at zero so the AWS CNI can be
  # removed before any node exists (aws_installation.py install_tf_cluster).
  system_asg_config = {
    name              = "system"
    instance_type     = var.system_node.instance_type
    cores             = var.system_node.cores
    memory            = var.system_node.memory
    min_size          = var.start_nodes ? var.system_node.min_size : 0
    max_size          = var.system_node.max_size
    desired_capacity  = var.start_nodes ? var.system_node.desired_capacity : 0
    max_pods          = var.system_node.max_pods
    enable_monitoring = var.system_node.enable_monitoring
  }
  asg_config = [for s in var.instance_sizes : {
    name                = s.name
    instance_type       = s.instance_type
    cores               = s.cores
    memory              = s.memory
    gpu                 = s.gpu
    accelerator         = s.accelerator
    min_size            = s.min_size
    max_size            = s.max_size
    desired_capacity    = s.desired_capacity
    max_pods            = s.max_pods
    spot_instance_types = s.spot_instance_types
    enable_monitoring   = s.enable_monitoring
  }]
  workers_additional_policies = var.workers_additional_policies

  # What _cluster_template_vars sets when the install brings no IAM of its own.
  manage_saturn_iam_resources  = true
  manage_cluster_iam_resources = true
  manage_worker_iam_resources  = true
  manage_ebs_iam_resources     = true
  manage_nfs_iam_resources     = var.network_filesystem_enabled
  manage_efs                   = var.network_filesystem_enabled
  workers_group_defaults       = {}
  cluster_iam_role_name        = ""
  ebs_iam_role_arn             = ""
  atlas_role_arn               = ""

  object_storage_enabled                = var.object_storage_enabled
  object_storage_upload_expiration_days = var.object_storage_upload_expiration_days

  depends_on = [terraform_data.validate]
}

############################
# What aws_installation.py did around the stacks
############################

# install_tf_cluster: delete the AWS VPC CNI while the cluster has no nodes
# (charts.py AWS_CNI_RESOURCES).
resource "terraform_data" "remove_aws_cni" {
  triggers_replace = [module.cluster.oidc_provider_arn]

  provisioner "local-exec" {
    command = "${path.module}/scripts/remove-aws-cni.sh ${local.cluster_name} ${var.region}"
  }
}

# Calico and CoreDNS, from the operator image, installed by hand before the
# operator: the operator is a pod, so it cannot start without a CNI, and its
# first step (exchanging the bootstrap token with the manager) needs cluster
# DNS. EKS's own CoreDNS cannot run on the tainted system nodes. saturn-aws
# installed both charts itself before anything else (apps_batch_1).
# Release names and namespaces are the ones the operator uses (calico and
# coredns, in kube-system), so the operator's first reconcile upgrades these
# releases and owns them from then on.
locals {
  charts_path = var.charts_path != "" ? var.charts_path : "${path.module}/.charts"

  system_node_scheduling = {
    nodeSelector = { "node.saturncloud.io/role" = "system" }
    tolerations = [{
      key      = "node.saturncloud.io/role"
      operator = "Equal"
      value    = "system"
      effect   = "NoSchedule"
    }]
  }

  calico_values = merge(local.system_node_scheduling, {
    cloudProvider = "aws"
    ipv4PoolCidr  = var.calico_ipv4_pool_cidr
    images = {
      cni             = "public.ecr.aws/saturncloud/calico/cni:v3.31.3"
      node            = "public.ecr.aws/saturncloud/calico/node:v3.31.3"
      kubeControllers = "public.ecr.aws/saturncloud/calico/kube-controllers:v3.31.3"
      typha           = "public.ecr.aws/saturncloud/calico/typha:v3.31.3"
    }
  })

  # The spec the operator gives its coredns CR (saturn-components.yaml).
  # saturn-aws 2026.02.01 has no CoreDNS image for Kubernetes above 1.32;
  # this is the one production AWS installs run on newer clusters.
  coredns_image = var.coredns_image != "" ? var.coredns_image : "602401143452.dkr.ecr.${var.region}.amazonaws.com/eks/coredns:v1.13.2-eksbuild.1"
  coredns_values = merge(local.system_node_scheduling, {
    cloudProvider = "aws"
    aws           = { region = var.region }
    clusterName   = local.cluster_name
    clusterDNSIP  = local.dns_service_ip
    images        = { coredns = local.coredns_image }
  })
}

resource "terraform_data" "calico" {
  count            = var.manage_helm ? 1 : 0
  triggers_replace = [terraform_data.remove_aws_cni.id]

  provisioner "local-exec" {
    command = "${path.module}/scripts/install-chart.sh ${local.cluster_name} ${var.region} calico ${local.charts_path}/calico"
    environment = {
      CHART_VALUES = yamlencode(local.calico_values)
    }
  }
}

# config.py CoreDNS._install: label EKS's CoreDNS objects for the coredns
# release, then install the chart over them.
resource "terraform_data" "coredns" {
  count            = var.manage_helm ? 1 : 0
  triggers_replace = [terraform_data.remove_aws_cni.id]

  provisioner "local-exec" {
    command = "${path.module}/scripts/adopt-coredns.sh ${local.cluster_name} ${var.region} && ${path.module}/scripts/install-chart.sh ${local.cluster_name} ${var.region} coredns ${local.charts_path}/coredns"
    environment = {
      CHART_VALUES = yamlencode(local.coredns_values)
    }
  }

  depends_on = [terraform_data.calico]
}

# install_addons: created with boto3 after the nodes start. Same versions
# and settings as aws_installation.py (kube_proxy_version,
# aws_ebs_csi_driver_version).
locals {
  addon_versions = {
    "1.34" = { kube_proxy = "v1.34.3-eksbuild.5", ebs_csi = "v1.56.0-eksbuild.1" }
    "1.35" = { kube_proxy = "v1.35.0-eksbuild.2", ebs_csi = "v1.56.0-eksbuild.1" }
  }
}

resource "aws_eks_addon" "kube_proxy" {
  count                       = var.start_nodes ? 1 : 0
  cluster_name                = local.cluster_name
  addon_name                  = "kube-proxy"
  addon_version               = local.addon_versions[var.kubernetes_version].kube_proxy
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.cluster, terraform_data.calico]
}

resource "aws_eks_addon" "ebs_csi" {
  count                       = var.start_nodes ? 1 : 0
  cluster_name                = local.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = local.addon_versions[var.kubernetes_version].ebs_csi
  service_account_role_arn    = module.cluster.ebs_csi_role_arn
  configuration_values        = file("${path.module}/saturn-aws/cluster/csi_config.json")
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # The controller needs cluster DNS to reach STS. saturn-aws created this
  # add-on after its coredns chart, and did not wait for it to become ACTIVE.
  depends_on = [aws_eks_addon.kube_proxy, terraform_data.coredns]
}
