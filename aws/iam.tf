# IRSA roles, copied from saturn-aws cluster/iam.tf.

# Role used by Atlas, fluent-bit and the docker secrets manager.
resource "aws_iam_role" "atlas" {
  name = "saturn-ui-${local.org_name}"
  path = "/saturn/"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : local.oidc_provider_arn
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${local.oidc_provider_id}:aud" : "sts.amazonaws.com"
          },
          "ForAnyValue:StringEquals" : {
            "${local.oidc_provider_id}:sub" : [
              "system:serviceaccount:saturn:saturnadmin",
              "system:serviceaccount:logging:fluent-bit",
              "system:serviceaccount:kube-system:docker-secrets-manager"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "atlas" {
  name = "atlas-role-policy"
  role = aws_iam_role.atlas.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "s3:*",
        "Resource" : [
          "arn:aws:s3:::${local.saturn_bucket_name}",
          "arn:aws:s3:::${local.saturn_bucket_name}/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : "ecr:*",
        "Resource" : "arn:aws:ecr:*:*:repository/saturn*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:CreateRepository",
          "ecr:GetAuthorizationToken",
          "ecr:DescribeRepositories"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeInstances",
          "ec2:DeleteSnapshot",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeVolumes",
          "ec2:CreateSnapshot",
          "ec2:DescribeSnapshots",
          "ec2:CreateVolume"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeAutoScalingGroups"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# Role for the EBS CSI controller.
#
# Kept byte-for-byte from saturn-aws: the Condition object repeats the
# "StringEquals" key, so when it is encoded only the second one (the :sub
# check) survives and the :aud check is dropped. Fixing it would change the
# trust policy, which is a security change to bring to the owner first.
resource "aws_iam_role" "ebs_csi" {
  name = "saturn-ebs-${local.org_name}"
  path = "/saturn/"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : local.oidc_provider_arn
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${local.oidc_provider_id}:aud" : "sts.amazonaws.com"
          },
          "StringEquals" : {
            "${local.oidc_provider_id}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}
