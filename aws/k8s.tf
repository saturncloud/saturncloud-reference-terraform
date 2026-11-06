# In-cluster pieces Terraform installs itself.

# aws-auth, as saturn-aws writes it. With authentication_mode = "API" EKS
# ignores this ConfigMap; it only takes effect in CONFIG_MAP or
# API_AND_CONFIG_MAP mode.
resource "kubernetes_config_map_v1" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(concat(
      [{
        rolearn  = aws_iam_role.workers.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }],
      [
        {
          rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/customer-admin-self-managed"
          username = "customer-admin-self-managed"
          groups   = ["system:masters"]
        },
        {
          rolearn  = aws_iam_role.atlas.arn
          username = "saturn-ui"
          groups   = ["system:masters"]
        },
      ],
    ))
  }

  depends_on = [aws_eks_access_entry.workers]
}

# Calico has to be the first thing in the cluster: the operator is itself a
# pod and cannot start without a CNI. This installs the calico chart from the
# operator image under the release name and namespace the operator uses
# (calico / kube-system), with the values the operator renders, so the
# operator's first reconcile upgrades this release in place and owns it from
# then on.
locals {
  calico_values = {
    cloudProvider = "aws"
    ipv4PoolCidr  = var.calico_ipv4_pool_cidr
    images = {
      cni             = "public.ecr.aws/saturncloud/calico/cni:v3.31.3"
      node            = "public.ecr.aws/saturncloud/calico/node:v3.31.3"
      kubeControllers = "public.ecr.aws/saturncloud/calico/kube-controllers:v3.31.3"
      typha           = "public.ecr.aws/saturncloud/calico/typha:v3.31.3"
    }
    nodeSelector = { "node.saturncloud.io/role" = "system" }
    tolerations = [{
      key      = "node.saturncloud.io/role"
      operator = "Equal"
      value    = "system"
      effect   = "NoSchedule"
    }]
  }
}

resource "helm_release" "calico" {
  count     = var.manage_helm ? 1 : 0
  name      = "calico"
  chart     = var.calico_chart_path != "" ? var.calico_chart_path : "${path.module}/.charts/calico"
  namespace = "kube-system"
  values    = [yamlencode(local.calico_values)]

  # Nothing can be Ready until nodes exist, and nodes wait for this release.
  wait = false

  depends_on = [aws_eks_addon.kube_proxy]

  lifecycle {
    # The operator takes the release over after install.
    ignore_changes = all
  }
}
