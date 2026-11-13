# IAM user used by saturn-cloud app

resource "aws_iam_role" "atlas" {
  count = var.manage_saturn_iam_resources ? 1 : 0
  name = "saturn-ui-${var.org_name}"
  path = "/saturn/"
  assume_role_policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": local.oidc_provider_arn
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.oidc_provider_id}:aud": "sts.amazonaws.com"
        },
        "ForAnyValue:StringEquals": {
          "${local.oidc_provider_id}:sub": [
            "system:serviceaccount:saturn:saturnadmin",
            "system:serviceaccount:logging:fluent-bit",
            "system:serviceaccount:kube-system:docker-secrets-manager"
          ]
        }
      }
    }
  ]
})
  tags = merge(
    var.tags,
    {
      app = "Saturn"
    },
  )
}


resource "aws_iam_role_policy" "atlas" {
  count = var.manage_saturn_iam_resources ? 1 : 0
  name = "atlas-role-policy"
  role = aws_iam_role.atlas[count.index].id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${var.saturn_bucket_name}",
                "arn:aws:s3:::${var.saturn_bucket_name}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "ecr:*",
            "Resource": "arn:aws:ecr:*:*:repository/saturn*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:CreateRepository",
                "ecr:GetAuthorizationToken",
                "ecr:DescribeRepositories"
             ],
             "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DeleteSnapshot",
                "ec2:CreateTags",
                "ec2:DeleteTags",
                "ec2:DescribeVolumes",
                "ec2:CreateSnapshot",
                "ec2:DescribeSnapshots",
                "ec2:CreateVolume"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeScalingActivities",
                "autoscaling:DescribeAutoScalingGroups"
            ],
            "Resource": "*"
        }
    ]
}
  EOF
}

resource "aws_iam_role" "ebs_csi" {
  count = var.manage_ebs_iam_resources ? 1 : 0
  name = "saturn-ebs-${var.org_name}"
  path = "/saturn/"
  assume_role_policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": local.oidc_provider_arn
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.oidc_provider_id}:aud": "sts.amazonaws.com",
          "${local.oidc_provider_id}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
})
  tags = merge(
    var.tags,
    {
      app = "Saturn"
    },
  )
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = var.manage_ebs_iam_resources ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi[0].name
}
