# Self-managed node groups (launch template + ASG), as in saturn-aws's
# cluster/workers.tf and saturn-cluster module. The system group carries the
# node.saturncloud.io/role=system taint; each workspace size gets an
# on-demand group and a spot_ group. Atlas and the cluster-autoscaler find
# them by the node.saturncloud.io/role label and the autoscaler tags.

locals {
  # Kubelet flags shared by every group. "medium" reserves less memory, as in saturn-aws.
  kubelet_common = [
    "--enforce-node-allocatable=pods",
    "--eviction-soft=memory.available<1Gi,nodefs.available<15%,imagefs.available<15%",
    "--eviction-soft-grace-period=memory.available=30s,nodefs.available=30s,imagefs.available=30s",
    "--eviction-max-pod-grace-period=60",
    "--eviction-minimum-reclaim=memory.available=1Gi,nodefs.available=2Gi,imagefs.available=2Gi",
  ]

  zone_labels = [
    "topology.ebs.csi.aws.com/zone=${local.worker_zone}",
    "topology.kubernetes.io/region=${var.region}",
    "topology.kubernetes.io/zone=${local.worker_zone}",
  ]

  # Autoscaler node-template tags every group carries, so it can scale from zero.
  zone_template_tags = {
    "k8s.io/cluster-autoscaler/node-template/label/topology.ebs.csi.aws.com/zone"            = local.worker_zone
    "k8s.io/cluster-autoscaler/node-template/label/failure-domain.beta.kubernetes.io/zone"   = local.worker_zone
    "k8s.io/cluster-autoscaler/node-template/label/failure-domain.beta.kubernetes.io/region" = var.region
    "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/zone"              = local.worker_zone
    "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/region"            = var.region
  }

  size_groups = merge([
    for size in var.instance_sizes : {
      for spot in [false, true] : (spot ? "spot_${size.name}" : size.name) => {
        role                = spot ? "spot_${size.name}" : size.name
        instance_type       = size.instance_type
        spot_instance_types = spot ? size.spot_instance_types : null
        min_size            = size.min_size
        max_size            = size.max_size
        desired_capacity    = size.desired_capacity
        enable_monitoring   = size.enable_monitoring
        has_gpu             = size.gpu > 0
        cpu_credits         = "unlimited"
        additional_sgs      = []
        kubelet_args = join(" ", concat(
          [format("--node-labels=%s", join(",", concat(
            [
              "node.saturnenterprise.io/role=${spot ? "spot_${size.name}" : size.name}",
              "node.saturncloud.io/role=${spot ? "spot_${size.name}" : size.name}",
            ],
            local.zone_labels,
            size.gpu > 0 ? ["k8s.amazonaws.com/accelerator=${size.accelerator}"] : [],
          )))],
          [
            "--max-pods=${size.max_pods}",
            size.name != "medium" ? "--kube-reserved=cpu=200m,memory=1Gi,ephemeral-storage=5Gi" : "--kube-reserved=cpu=200m,memory=500Mi,ephemeral-storage=5Gi",
            size.name != "medium" ? "--system-reserved=cpu=200m,memory=1Gi,ephemeral-storage=5Gi" : "--system-reserved=cpu=200m,memory=500Mi,ephemeral-storage=5Gi",
          ],
          local.kubelet_common,
        ))
        tags = merge(
          local.zone_template_tags,
          size.gpu > 0 ? { "k8s.io/cluster-autoscaler/node-template/resources/nvidia.com/gpu" = tostring(size.gpu) } : {},
          {
            "k8s.io/cluster-autoscaler/node-template/label/node.saturnenterprise.io/role" = spot ? "spot_${size.name}" : size.name
            "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role"      = spot ? "spot_${size.name}" : size.name
          },
        )
      }
    }
  ]...)

  system_group = {
    system = {
      role                = "system"
      instance_type       = var.system_node.instance_type
      spot_instance_types = null
      min_size            = var.system_node.min_size
      max_size            = var.system_node.max_size
      desired_capacity    = var.system_node.desired_capacity
      enable_monitoring   = var.system_node.enable_monitoring
      has_gpu             = false
      # saturn-aws leaves the system group on the module default.
      cpu_credits    = "standard"
      additional_sgs = [aws_security_group.system_nodes.id]
      kubelet_args = join(" ", concat(
        [
          "--node-labels=${join(",", concat(local.zone_labels, ["node.saturnenterprise.io/role=system", "node.saturncloud.io/role=system"]))}",
          "--register-with-taints node.saturncloud.io/role=system:NoSchedule",
          "--max-pods=${var.system_node.max_pods}",
          "--kube-reserved=cpu=200m,memory=1Gi,ephemeral-storage=5Gi",
          "--system-reserved=cpu=200m,memory=1Gi,ephemeral-storage=5Gi",
        ],
        local.kubelet_common,
      ))
      tags = merge(local.zone_template_tags, {
        "k8s.io/cluster-autoscaler/node-template/label/node.saturnenterprise.io/role" = "system"
        "k8s.io/cluster-autoscaler/node-template/taint/node.saturncloud.io/role"      = "system:NoSchedule"
        "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role"      = "system"
      })
    }
  }

  node_groups = merge(local.size_groups, local.system_group)

  root_volume_size = 100
}

############################
# Security groups
############################

resource "aws_security_group" "workers" {
  name_prefix = local.cluster_name
  description = "Security group for all nodes in the cluster."
  vpc_id      = aws_vpc.this.id
  tags = {
    Name                                          = "${local.cluster_name}-eks_worker_sg"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

resource "aws_security_group_rule" "workers_egress_internet" {
  description       = "Allow nodes all egress to the Internet."
  protocol          = "-1"
  security_group_id = aws_security_group.workers.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "workers_ingress_self" {
  description              = "Allow node to communicate with each other."
  protocol                 = "-1"
  security_group_id        = aws_security_group.workers.id
  source_security_group_id = aws_security_group.workers.id
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "workers_ingress_cluster" {
  description              = "Allow workers pods to receive communication from the cluster control plane."
  protocol                 = "tcp"
  security_group_id        = aws_security_group.workers.id
  source_security_group_id = aws_security_group.cluster.id
  from_port                = 1025
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "workers_ingress_cluster_https" {
  description              = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane."
  protocol                 = "tcp"
  security_group_id        = aws_security_group.workers.id
  source_security_group_id = aws_security_group.cluster.id
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group" "system_nodes" {
  name        = "${local.cluster_name}-system-nodes"
  description = "Group for targeting traffic from system nodes"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.cluster_name}-system-nodes"
  }

  # The worker group above carries the system nodes' real rules. This group
  # only exists to be referenced; the egress rule keeps it from being empty.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# IAM
############################

resource "aws_iam_role" "workers" {
  name_prefix           = local.cluster_name
  assume_role_policy    = data.aws_iam_policy_document.workers_assume_role.json
  force_detach_policies = true
}

data "aws_iam_policy_document" "workers_assume_role" {
  statement {
    sid     = "EKSWorkerAssumeRole"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "workers" {
  for_each = merge({
    AmazonEKSWorkerNodePolicy = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    # Still attached although the AWS CNI is not installed, as in saturn-aws.
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    worker_autoscaling                 = aws_iam_policy.worker_autoscaling.arn
  }, { for i, arn in var.workers_additional_policies : "additional_${i}" => arn })
  policy_arn = each.value
  role       = aws_iam_role.workers.name
}

resource "aws_iam_role_policy" "ecr_pull_through" {
  name = "worker_ecr_pull_through"
  role = aws_iam_role.workers.name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:BatchImportUpstreamImage",
          "ecr:CreateRepository"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "worker_autoscaling" {
  name_prefix = "eks-worker-autoscaling-${local.cluster_name}"
  description = "EKS worker node autoscaling policy for cluster ${local.cluster_name}"
  policy      = data.aws_iam_policy_document.worker_autoscaling.json
}

data "aws_iam_policy_document" "worker_autoscaling" {
  statement {
    sid    = "eksWorkerAutoscalingAll"
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "eksWorkerAutoscalingOwn"
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${local.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }
  }
}

# One instance profile per group, as saturn-aws does; all share the worker role.
resource "aws_iam_instance_profile" "workers" {
  for_each    = local.node_groups
  name_prefix = local.cluster_name
  role        = aws_iam_role.workers.id
}

############################
# Launch templates and ASGs
############################

data "aws_ssm_parameter" "ami" {
  for_each = {
    standard = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
    nvidia   = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2023/x86_64/nvidia/recommended/image_id"
  }
  name = each.value
}

resource "aws_launch_template" "workers" {
  for_each    = local.node_groups
  name_prefix = "${local.cluster_name}-${each.key}"

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = concat([aws_security_group.workers.id], each.value.additional_sgs)
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.workers[each.key].name
  }

  image_id      = each.value.has_gpu ? data.aws_ssm_parameter.ami["nvidia"].value : data.aws_ssm_parameter.ami["standard"].value
  instance_type = each.value.instance_type
  user_data = base64encode(templatefile("${path.module}/templates/userdata.sh.tpl", {
    cluster_name        = aws_eks_cluster.this.name
    endpoint            = aws_eks_cluster.this.endpoint
    cluster_auth_base64 = aws_eks_cluster.this.certificate_authority[0].data
    service_ipv4_cidr   = var.service_ipv4_cidr
    pre_userdata        = "export SERVICE_IPV4_CIDR=${var.service_ipv4_cidr}"
    additional_userdata = ""
    kubelet_extra_args  = each.value.kubelet_args
  }))

  ebs_optimized = true

  credit_specification {
    cpu_credits = each.value.cpu_credits
  }

  monitoring {
    enabled = each.value.enable_monitoring
  }

  placement {
    tenancy = "default"
  }

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = local.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.tags, { Name = "${local.cluster_name}-${each.key}-eks_asg" })
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${local.cluster_name}-${each.key}-eks_asg" })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "workers" {
  for_each    = local.node_groups
  name_prefix = "${local.cluster_name}-${each.key}"

  min_size              = each.value.min_size
  max_size              = each.value.max_size
  desired_capacity      = each.value.desired_capacity
  vpc_zone_identifier   = [aws_subnet.private[0].id]
  protect_from_scale_in = true
  suspended_processes   = ["AZRebalance"]

  dynamic "mixed_instances_policy" {
    for_each = each.value.spot_instance_types != null ? [1] : []
    content {
      instances_distribution {
        on_demand_allocation_strategy            = "prioritized"
        on_demand_base_capacity                  = 0
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "capacity-optimized"
        spot_instance_pools                      = 0
      }
      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.workers[each.key].id
          version            = "$Latest"
        }
        dynamic "override" {
          for_each = each.value.spot_instance_types
          content {
            instance_type = override.value
          }
        }
      }
    }
  }

  dynamic "launch_template" {
    for_each = each.value.spot_instance_types == null ? [1] : []
    content {
      id      = aws_launch_template.workers[each.key].id
      version = "$Latest"
    }
  }

  dynamic "tag" {
    for_each = merge(
      {
        Name                                          = "${local.cluster_name}-${each.key}-eks_asg"
        "kubernetes.io/cluster/${local.cluster_name}" = "owned"
      },
      local.tags,
      each.value.tags,
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  dynamic "tag" {
    for_each = {
      "k8s.io/cluster-autoscaler/enabled"                                   = "true"
      "k8s.io/cluster-autoscaler/${local.cluster_name}"                     = local.cluster_name
      "k8s.io/cluster-autoscaler/node-template/resources/ephemeral-storage" = "${local.root_volume_size}Gi"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }

  # Calico has to be in place before the first node registers, or the node
  # never gets pod networking (see k8s.tf).
  depends_on = [
    aws_eks_access_entry.workers,
    aws_eks_addon.kube_proxy,
    helm_release.calico,
  ]

  lifecycle {
    create_before_destroy = true
    # The cluster-autoscaler owns desired capacity once the cluster runs.
    ignore_changes = [desired_capacity]
  }
}
