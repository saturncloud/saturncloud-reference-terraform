# Worker Groups definition for autoscaling

locals {
  worker_groups_launch_template = {
    for group in concat(
      [
        # on-demand ASGS
        for group in var.asg_config : {
          name                  = group["name"]
          asg_min_size          = tostring(group["min_size"])
          asg_max_size          = tostring(group["max_size"])
          asg_desired_capacity  = tostring(group["desired_capacity"])
          instance_type         = group["instance_type"]
          autoscaling_enabled   = true
          protect_from_scale_in = true
          subnets               = var.worker_subnet_ids
          pre_userdata          = "export SERVICE_IPV4_CIDR=${var.service_ipv4_cidr}"
          enable_monitoring     = group["enable_monitoring"]
          bootstrap_extra_args  = ""
          kubelet_extra_args    = join(" ", [
            format("--node-labels=%s", join(",", concat([
              "node.saturnenterprise.io/role=${group["name"]}",
              "node.saturncloud.io/role=${group["name"]}",
              "topology.ebs.csi.aws.com/zone=${var.worker_zone}",
              "topology.kubernetes.io/region=${var.region}",
              "topology.kubernetes.io/zone=${var.worker_zone}",
            ], group["gpu"] > 0 ? [
              "k8s.amazonaws.com/accelerator=${group["accelerator"]}"
            ] : []))),
            "--max-pods=${group["max_pods"]}",
            group["name"] != "medium" ? "--kube-reserved=cpu=200m,memory=1Gi,ephemeral-storage=5Gi" : "--kube-reserved=cpu=200m,memory=500Mi,ephemeral-storage=5Gi",
            group["name"] != "medium" ? "--system-reserved=cpu=200m,memory=1Gi,ephemeral-storage=5Gi" : "--system-reserved=cpu=200m,memory=500Mi,ephemeral-storage=5Gi",
            "--enforce-node-allocatable=pods",
            "--eviction-soft=memory.available<1Gi,nodefs.available<15%,imagefs.available<15%",
            "--eviction-soft-grace-period=memory.available=30s,nodefs.available=30s,imagefs.available=30s",
            "--eviction-max-pod-grace-period=60",
            "--eviction-minimum-reclaim=memory.available=1Gi,nodefs.available=2Gi,imagefs.available=2Gi"
          ])
          root_encrypted        = true
          ami_id                = group["gpu"] > 0 ? var.gpu_ami : var.cpu_ami
          has_gpu               = group["gpu"] > 0
          cpu_credits           = "unlimited"
          tags = concat(
            group["gpu"] > 0 ? [
              {
              key = "k8s.io/cluster-autoscaler/node-template/resources/nvidia.com/gpu"
              value = group["gpu"]
              propagate_at_launch = true
              }
            ] : [],
            [
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/topology.ebs.csi.aws.com/zone"
                value = "${var.worker_zone}",
                propagate_at_launch = true
              },
              {
                key = "app"
                value = "Saturn"
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/node.saturnenterprise.io/role"
                value = "${group["name"]}"
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role"
                value = "${group["name"]}"
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/failure-domain.beta.kubernetes.io/zone"
                value = var.worker_zone
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/failure-domain.beta.kubernetes.io/region"
                value = var.region
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/zone"
                value = var.worker_zone
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/region"
                value = var.region
                propagate_at_launch = true
              }
            ]
          ),
        }
      ],
      [
        # spot ASGS
        for group in var.asg_config : {
          name                  = "spot_${group["name"]}"
          asg_min_size          = tostring(group["min_size"])
          asg_max_size          = tostring(group["max_size"])
          asg_desired_capacity  = tostring(group["desired_capacity"])
          override_instance_types = group["spot_instance_types"]
          # empty means defaults to on-demand prices
          spot_max_price           = ""
          spot_allocation_strategy = "capacity-optimized"
          # this is not required for capacity strategy, but we need to set it explicitly to 0
          spot_instance_pools      = "0"
          suspended_processes      = ["AZRebalance"]
          autoscaling_enabled   = true
          protect_from_scale_in = true
          subnets               = var.worker_subnet_ids
          pre_userdata          = "export SERVICE_IPV4_CIDR=${var.service_ipv4_cidr}"
          enable_monitoring     = group["enable_monitoring"]
          bootstrap_extra_args  = ""
          kubelet_extra_args    = join(" ", [
            format("--node-labels=%s", join(",", concat([
              "node.saturnenterprise.io/role=spot_${group["name"]}",
              "node.saturncloud.io/role=spot_${group["name"]}",
              "topology.ebs.csi.aws.com/zone=${var.worker_zone}",
              "topology.kubernetes.io/region=${var.region}",
              "topology.kubernetes.io/zone=${var.worker_zone}",
            ], group["gpu"] > 0 ? [
              "k8s.amazonaws.com/accelerator=${group["accelerator"]}"
            ] : []))),
            "--max-pods=${group["max_pods"]}",
            group["name"] != "medium" ? "--kube-reserved=cpu=200m,memory=1Gi,ephemeral-storage=5Gi" : "--kube-reserved=cpu=200m,memory=500Mi,ephemeral-storage=5Gi",
            group["name"] != "medium" ? "--system-reserved=cpu=200m,memory=1Gi,ephemeral-storage=5Gi" : "--system-reserved=cpu=200m,memory=500Mi,ephemeral-storage=5Gi",
            "--enforce-node-allocatable=pods",
            "--eviction-soft=memory.available<1Gi,nodefs.available<15%,imagefs.available<15%",
            "--eviction-soft-grace-period=memory.available=30s,nodefs.available=30s,imagefs.available=30s",
            "--eviction-max-pod-grace-period=60",
            "--eviction-minimum-reclaim=memory.available=1Gi,nodefs.available=2Gi,imagefs.available=2Gi"
          ])
          root_encrypted        = true
          ami_id                = group["gpu"] > 0 ? var.gpu_ami : var.cpu_ami
          has_gpu               = group["gpu"] > 0
          cpu_credits           = "unlimited"
          tags = concat(
            group["gpu"] > 0 ? [
              {
              key = "k8s.io/cluster-autoscaler/node-template/resources/nvidia.com/gpu"
              value = group["gpu"]
              propagate_at_launch = true
              }
            ] : [],
            [
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/topology.ebs.csi.aws.com/zone"
                value = "${var.worker_zone}",
                propagate_at_launch = true
              },
              {
                key = "app"
                value = "Saturn"
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/node.saturnenterprise.io/role"
                value = "spot_${group["name"]}"
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role"
                value = "spot_${group["name"]}"
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/failure-domain.beta.kubernetes.io/zone"
                value = var.worker_zone
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/failure-domain.beta.kubernetes.io/region"
                value = var.region
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/zone"
                value = var.worker_zone
                propagate_at_launch = true
              },
              {
                key = "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/region"
                value = var.region
                propagate_at_launch = true
              }
            ]
          ),
        }
      ],
      [
        # system node asg
        {
          name                          = "system"
          asg_min_size                  = tostring(var.system_asg_config["min_size"])
          asg_max_size                  = tostring(var.system_asg_config["max_size"])
          asg_desired_capacity          = tostring(var.system_asg_config["desired_capacity"])
          instance_type                 = var.system_asg_config["instance_type"]
          autoscaling_enabled           = true
          protect_from_scale_in         = true
          subnets                       = var.worker_subnet_ids
          pre_userdata                  = "export SERVICE_IPV4_CIDR=${var.service_ipv4_cidr}"
          enable_monitoring             = var.system_asg_config["enable_monitoring"]
          bootstrap_extra_args          = ""
          kubelet_extra_args            = "--node-labels=topology.ebs.csi.aws.com/zone=${var.worker_zone},topology.kubernetes.io/region=${var.region},topology.kubernetes.io/zone=${var.worker_zone},node.saturnenterprise.io/role=system,node.saturncloud.io/role=system --register-with-taints node.saturncloud.io/role=system:NoSchedule --max-pods=${var.system_asg_config["max_pods"]} --kube-reserved=cpu=200m,memory=1Gi,ephemeral-storage=5Gi --system-reserved=cpu=200m,memory=1Gi,ephemeral-storage=5Gi --enforce-node-allocatable=pods --eviction-soft=memory.available<1Gi,nodefs.available<15%,imagefs.available<15% --eviction-soft-grace-period=memory.available=30s,nodefs.available=30s,imagefs.available=30s --eviction-max-pod-grace-period=60 --eviction-minimum-reclaim=memory.available=1Gi,nodefs.available=2Gi,imagefs.available=2Gi"
          root_encrypted                = true
          ami_id                        = var.cpu_ami
          has_gpu                       = false
          additional_security_group_ids = [aws_security_group.system_nodes.id]
          tags = [
            {
              key = "app"
              value = "Saturn"
              propagate_at_launch = true
            },
            {
                key = "k8s.io/cluster-autoscaler/node-template/label/topology.ebs.csi.aws.com/zone"
                value = "${var.worker_zone}",
                propagate_at_launch = true
            },
            {
              key = "k8s.io/cluster-autoscaler/node-template/label/node.saturnenterprise.io/role"
              value = "system"
              propagate_at_launch = true
            },
            {
              key = "k8s.io/cluster-autoscaler/node-template/taint/node.saturncloud.io/role"
              value = "system:NoSchedule"
              propagate_at_launch = true
            },
            {
              key = "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role"
              value = "system"
              propagate_at_launch = true
            },
            {
              key = "k8s.io/cluster-autoscaler/node-template/label/failure-domain.beta.kubernetes.io/zone"
              value = var.worker_zone
              propagate_at_launch = true
            },
            {
              key = "k8s.io/cluster-autoscaler/node-template/label/failure-domain.beta.kubernetes.io/region"
              value = var.region
              propagate_at_launch = true
            },
            {
              key = "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/zone"
              value = var.worker_zone
              propagate_at_launch = true
            },
            {
              key = "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/region"
              value = var.region
              propagate_at_launch = true
            }
          ],
        }
      ]
    ) : group["name"] => group
  }
}
