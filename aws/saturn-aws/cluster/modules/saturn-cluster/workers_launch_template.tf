# Worker Groups using Launch Templates

resource "aws_autoscaling_group" "workers_launch_template" {
  for_each    = var.worker_groups_launch_template
  name_prefix = join(
    "-",
    compact(
      [
        aws_eks_cluster.this.name,
        each.key,
        lookup(each.value, "asg_recreate_on_change", local.workers_group_defaults["asg_recreate_on_change"]) ? random_pet.workers_launch_template[each.key].id : ""
      ]
    )
  )
  desired_capacity = lookup(
    each.value,
    "asg_desired_capacity",
    local.workers_group_defaults["asg_desired_capacity"],
  )
  max_size = lookup(
    each.value,
    "asg_max_size",
    local.workers_group_defaults["asg_max_size"],
  )
  min_size = lookup(
    each.value,
    "asg_min_size",
    local.workers_group_defaults["asg_min_size"],
  )
  force_delete = lookup(
    each.value,
    "asg_force_delete",
    local.workers_group_defaults["asg_force_delete"],
  )
  target_group_arns = lookup(
    each.value,
    "target_group_arns",
    local.workers_group_defaults["target_group_arns"]
  )
  service_linked_role_arn = lookup(
    each.value,
    "service_linked_role_arn",
    local.workers_group_defaults["service_linked_role_arn"],
  )
  vpc_zone_identifier = lookup(
    each.value,
    "subnets",
    local.workers_group_defaults["subnets"]
  )
  protect_from_scale_in = lookup(
    each.value,
    "protect_from_scale_in",
    local.workers_group_defaults["protect_from_scale_in"],
  )
  suspended_processes = lookup(
    each.value,
    "suspended_processes",
    local.workers_group_defaults["suspended_processes"]
  )
  enabled_metrics = lookup(
    each.value,
    "enabled_metrics",
    local.workers_group_defaults["enabled_metrics"]
  )
  placement_group = lookup(
    each.value,
    "placement_group",
    local.workers_group_defaults["placement_group"],
  )
  termination_policies = lookup(
    each.value,
    "termination_policies",
    local.workers_group_defaults["termination_policies"]
  )

  dynamic mixed_instances_policy {
    iterator = item
    for_each = (lookup(each.value, "override_instance_types", null) != null) || (lookup(each.value, "on_demand_allocation_strategy", null) != null) ? [each.value] : []

    content {
      instances_distribution {
        on_demand_allocation_strategy = lookup(
          item.value,
          "on_demand_allocation_strategy",
          "prioritized",
        )
        on_demand_base_capacity = lookup(
          item.value,
          "on_demand_base_capacity",
          local.workers_group_defaults["on_demand_base_capacity"],
        )
        on_demand_percentage_above_base_capacity = lookup(
          item.value,
          "on_demand_percentage_above_base_capacity",
          local.workers_group_defaults["on_demand_percentage_above_base_capacity"],
        )
        spot_allocation_strategy = lookup(
          item.value,
          "spot_allocation_strategy",
          local.workers_group_defaults["spot_allocation_strategy"],
        )
        spot_instance_pools = lookup(
          item.value,
          "spot_instance_pools",
          local.workers_group_defaults["spot_instance_pools"],
        )
        spot_max_price = lookup(
          item.value,
          "spot_max_price",
          local.workers_group_defaults["spot_max_price"],
        )
      }

      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.workers_launch_template[each.key].id
          version = lookup(
            each.value,
            "launch_template_version",
            local.workers_group_defaults["launch_template_version"],
          )
        }

        dynamic "override" {
          for_each = lookup(
            each.value,
            "override_instance_types",
            local.workers_group_defaults["override_instance_types"]
          )

          content {
            instance_type = override.value
          }
        }

      }
    }
  }
  dynamic launch_template {
    iterator = item
    for_each = (lookup(each.value, "override_instance_types", null) != null) || (lookup(each.value, "on_demand_allocation_strategy", null) != null) ? [] : [each.value]

    content {
      id = aws_launch_template.workers_launch_template[each.key].id
      version = lookup(
        each.value,
        "launch_template_version",
        local.workers_group_defaults["launch_template_version"],
      )
    }
  }

  dynamic "initial_lifecycle_hook" {
    for_each = var.worker_create_initial_lifecycle_hooks ? lookup(each.value, "asg_initial_lifecycle_hooks", local.workers_group_defaults["asg_initial_lifecycle_hooks"]) : []
    content {
      name                    = initial_lifecycle_hook.value["name"]
      lifecycle_transition    = initial_lifecycle_hook.value["lifecycle_transition"]
      notification_metadata   = lookup(initial_lifecycle_hook.value, "notification_metadata", null)
      heartbeat_timeout       = lookup(initial_lifecycle_hook.value, "heartbeat_timeout", null)
      notification_target_arn = lookup(initial_lifecycle_hook.value, "notification_target_arn", null)
      role_arn                = lookup(initial_lifecycle_hook.value, "role_arn", null)
      default_result          = lookup(initial_lifecycle_hook.value, "default_result", null)
    }
  }

  tag {
    key                 = "Name"
    value               = "${aws_eks_cluster.this.name}-${each.key}-eks_asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${aws_eks_cluster.this.name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key = "k8s.io/cluster-autoscaler/${lookup(
      each.value,
      "autoscaling_enabled",
      local.workers_group_defaults["autoscaling_enabled"],
    ) ? "enabled" : "disabled"}"
    value               = "true"
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${aws_eks_cluster.this.name}"
    value               = aws_eks_cluster.this.name
    propagate_at_launch = false
  }

  tag {
    key = "k8s.io/cluster-autoscaler/node-template/resources/ephemeral-storage"
    value = "${lookup(
      each.value,
      "root_volume_size",
      local.workers_group_defaults["root_volume_size"],
    )}Gi"
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = concat(
      local.asg_tags,
      lookup(
        each.value,
        "tags",
        local.workers_group_defaults["tags"]
      )
    )
    content {
      key                 = tag.value["key"]
      value               = tag.value["value"]
      propagate_at_launch = tag.value["propagate_at_launch"]
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

resource "aws_launch_template" "workers_launch_template" {
  for_each    = var.worker_groups_launch_template
  name_prefix = "${aws_eks_cluster.this.name}-${each.key}"

  network_interfaces {
    associate_public_ip_address = lookup(
      each.value,
      "public_ip",
      local.workers_group_defaults["public_ip"],
    )
    delete_on_termination = lookup(
      each.value,
      "eni_delete",
      local.workers_group_defaults["eni_delete"],
    )
    security_groups = flatten([
      local.worker_security_group_id,
      var.worker_additional_security_group_ids,
      lookup(
        each.value,
        "additional_security_group_ids",
        local.workers_group_defaults["additional_security_group_ids"],
      ),
    ])
  }

  iam_instance_profile {
    name = var.manage_worker_iam_resources ? aws_iam_instance_profile.workers_launch_template[each.key].name : data.aws_iam_instance_profile.custom_worker_group_launch_template_iam_instance_profile[each.key].name
  }

  # Select AMI based on ami_type or legacy has_gpu logic
  image_id = coalesce(
    lookup(each.value, "ami_id", ""),
    # Use explicit ami_type if provided
    lookup(each.value, "ami_type", "") != "" ? data.aws_ssm_parameter.ami[lookup(each.value, "ami_type", var.default_ami_type)].value : "",
    # Legacy GPU detection: use NVIDIA AMI if has_gpu is true
    lookup(each.value, "has_gpu", false) ? data.aws_ssm_parameter.ami["AL2023_x86_64_NVIDIA"].value : "",
    # Default to standard AL2023 AMI
    data.aws_ssm_parameter.ami["AL2023_x86_64_STANDARD"].value,
  )
  instance_type = lookup(
    each.value,
    "instance_type",
    local.workers_group_defaults["instance_type"],
  )
  key_name = lookup(
    each.value,
    "key_name",
    local.workers_group_defaults["key_name"],
  )
  user_data = base64encode(
    local.launch_template_userdata[each.key],
  )

  ebs_optimized = lookup(
    each.value,
    "ebs_optimized",
    ! contains(
      local.ebs_optimized_not_supported,
      lookup(
        each.value,
        "instance_type",
        local.workers_group_defaults["instance_type"],
      )
    )
  )

  credit_specification {
    cpu_credits = lookup(
      each.value,
      "cpu_credits",
      local.workers_group_defaults["cpu_credits"]
    )
  }

  monitoring {
    enabled = lookup(
      each.value,
      "enable_monitoring",
      local.workers_group_defaults["enable_monitoring"],
    )
  }

  placement {
    tenancy = lookup(
      each.value,
      "launch_template_placement_tenancy",
      local.workers_group_defaults["launch_template_placement_tenancy"],
    )
    group_name = lookup(
      each.value,
      "launch_template_placement_group",
      local.workers_group_defaults["launch_template_placement_group"],
    )
  }

  dynamic instance_market_options {
    for_each = lookup(each.value, "market_type", null) == null ? [] : [lookup(each.value, "market_type", null)]
    content {
      market_type = instance_market_options.value
    }
  }

  metadata_options {
    http_tokens = "required"           # This requires IMDSv2 to be used
    http_put_response_hop_limit = 2    # Limits the number of hops for requests
    http_endpoint = "enabled"          # Enables the metadata endpoint
  }

  block_device_mappings {
    device_name = lookup(
      each.value,
      "root_block_device_name",
      local.workers_group_defaults["root_block_device_name"],
    )

    ebs {
      volume_size = lookup(
        each.value,
        "root_volume_size",
        local.workers_group_defaults["root_volume_size"],
      )
      volume_type = lookup(
        each.value,
        "root_volume_type",
        local.workers_group_defaults["root_volume_type"],
      )
      iops = lookup(
        each.value,
        "root_iops",
        local.workers_group_defaults["root_iops"],
      )
      encrypted = lookup(
        each.value,
        "root_encrypted",
        local.workers_group_defaults["root_encrypted"],
      )
      kms_key_id = lookup(
        each.value,
        "root_kms_key_id",
        local.workers_group_defaults["root_kms_key_id"],
      )
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      {
        "Name" = "${aws_eks_cluster.this.name}-${each.key}-eks_asg"
      },
      var.tags,
    )
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      {
        "Name" = "${aws_eks_cluster.this.name}-${each.key}-eks_asg"
      },
      var.tags,
    )
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "random_pet" "workers_launch_template" {
  for_each  = var.worker_groups_launch_template

  separator = "-"
  length    = 2

  keepers = {
    lt_name = join(
      "-",
      compact(
        [
          aws_launch_template.workers_launch_template[each.key].name,
          aws_launch_template.workers_launch_template[each.key].latest_version
        ]
      )
    )
  }
}

resource "aws_iam_instance_profile" "workers_launch_template" {
  for_each    = {for k, v in var.worker_groups_launch_template : k => v if var.manage_worker_iam_resources}
  name_prefix = aws_eks_cluster.this.name
  role = lookup(
    each.value,
    "iam_role_id",
    local.default_iam_role_id,
  )
  path = var.iam_path
}
