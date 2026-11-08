locals {
  # SSM parameter paths for EKS optimized AMIs (AL2023 only)
  ami_type_to_ssm_param = {
    AL2023_x86_64_STANDARD = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
    AL2023_x86_64_NVIDIA   = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/x86_64/nvidia/recommended/image_id"
    AL2023_ARM_64_STANDARD = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/arm64/standard/recommended/image_id"
    AL2023_ARM_64_NVIDIA   = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/arm64/nvidia/recommended/image_id"
  }
}

data "aws_iam_policy_document" "workers_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Get AMI IDs from SSM parameters
data "aws_ssm_parameter" "ami" {
  for_each = local.ami_type_to_ssm_param
  name     = each.value
}


data "aws_iam_policy_document" "cluster_assume_role_policy" {
  statement {
    sid = "EKSClusterAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "template_file" "kubeconfig" {
  template = file("${path.module}/templates/kubeconfig.tpl")

  vars = {
    kubeconfig_name           = local.kubeconfig_name
    endpoint                  = aws_eks_cluster.this.endpoint
    cluster_auth_base64       = aws_eks_cluster.this.certificate_authority[0].data
    aws_authenticator_command = var.kubeconfig_aws_authenticator_command
    aws_authenticator_command_args = length(var.kubeconfig_aws_authenticator_command_args) > 0 ? "        - ${join(
      "\n        - ",
      var.kubeconfig_aws_authenticator_command_args,
      )}" : "        - ${join(
      "\n        - ",
      formatlist("\"%s\"", ["token", "-i", aws_eks_cluster.this.name]),
    )}"
    aws_authenticator_additional_args = length(var.kubeconfig_aws_authenticator_additional_args) > 0 ? "        - ${join(
      "\n        - ",
      var.kubeconfig_aws_authenticator_additional_args,
    )}" : ""
    aws_authenticator_env_variables = length(var.kubeconfig_aws_authenticator_env_variables) > 0 ? "      env:\n${join(
      "\n",
      data.template_file.aws_authenticator_env_variables.*.rendered,
    )}" : ""
  }
}

data "template_file" "aws_authenticator_env_variables" {
  count = length(var.kubeconfig_aws_authenticator_env_variables)

  template = <<EOF
        - name: $${key}
          value: $${value}
EOF


  vars = {
    value = values(var.kubeconfig_aws_authenticator_env_variables)[count.index]
    key   = keys(var.kubeconfig_aws_authenticator_env_variables)[count.index]
  }
}

locals {
  launch_template_userdata = {
    for name, group in var.worker_groups_launch_template:
      name => templatefile(
        lookup(
          group,
          "userdata_template_file",
          lookup(group, "platform", local.workers_group_defaults["platform"]) == "windows"
            ? "${path.module}/templates/userdata_windows.tpl"
            : "${path.module}/templates/userdata.sh.tpl"
        ),
        merge({
          cluster_name        = aws_eks_cluster.this.name
          endpoint            = aws_eks_cluster.this.endpoint
          cluster_auth_base64 = aws_eks_cluster.this.certificate_authority[0].data
          service_ipv4_cidr = var.service_ipv4_cidr
          pre_userdata = lookup(
            group,
            "pre_userdata",
            local.workers_group_defaults["pre_userdata"],
          )
          additional_userdata = lookup(
            group,
            "additional_userdata",
            local.workers_group_defaults["additional_userdata"],
          )
          bootstrap_extra_args = lookup(
            group,
            "bootstrap_extra_args",
            local.workers_group_defaults["bootstrap_extra_args"],
          )
          kubelet_extra_args = lookup(
            group,
            "kubelet_extra_args",
            local.workers_group_defaults["kubelet_extra_args"],
          )
          },
          lookup(
            group,
            "userdata_template_extra_args",
            local.workers_group_defaults["userdata_template_extra_args"]
          )
        )
      )
  }
}

data "aws_iam_role" "custom_cluster_iam_role" {
  count = var.manage_cluster_iam_resources ? 0 : 1
  name  = var.cluster_iam_role_name
}

data "aws_iam_instance_profile" "custom_worker_group_launch_template_iam_instance_profile" {
  for_each = {for k, v in var.worker_groups_launch_template : k => v if !var.manage_worker_iam_resources}
  name = local.workers_group_defaults["iam_instance_profile_name"]
}
