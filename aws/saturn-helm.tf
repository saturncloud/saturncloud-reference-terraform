# The Saturn operator, with the AWS settings saturn-aws used to pass to each
# chart (aws_installation.py get_atlas, get_traefik, get_ssh_proxy, ...).
# The operator fills in images, the domain and the tokens itself.

locals {
  saturn_base_url = "https://app.${local.saturn_domain}"
  ssh_domain      = "ssh.${local.saturn_domain}"

  # Atlas's instance sizes: the same objects saturn-aws writes into
  # instanceConfig, one per instance_sizes entry.
  instance_config = {
    default_cpu = var.default_cpu_size
    default_gpu = try([for s in var.instance_sizes : s.name if s.gpu > 0][0], "")
    sizes = [for s in var.instance_sizes : {
      name                 = s.name
      display_name         = s.display_name
      min_size             = s.min_size
      max_size             = s.max_size
      desired_capacity     = s.desired_capacity
      instance_type        = s.instance_type
      spot_instance_types  = s.spot_instance_types
      max_pods             = s.max_pods
      gpu                  = s.gpu
      cores                = s.cores
      memory               = s.memory
      reserved_memory      = s.reserved_memory
      accelerator          = s.accelerator
      enable_monitoring    = s.enable_monitoring
      node_affinity_config = null
    }]
  }

  public_subnet_ids = module.vpc.vpc_public_subnets

  saturn_helm_values = {
    createNamespaces = true

    clusterName      = local.cluster_name
    cloudProvider    = "aws"
    region           = var.region
    availabilityZone = local.worker_zone
    domain           = local.saturn_domain
    baseUrl          = local.saturn_base_url
    sshDomain        = local.ssh_domain
    adminEmail       = var.saturn_admin_email
    customerName     = var.saturn_customer_name
    bootstrapToken   = var.saturn_bootstrap_token
    managerURI       = var.saturn_manager_uri
    saturnManagerUri = var.saturn_manager_uri
    isEnterprise     = true

    imageBuildNodeRole = var.default_cpu_size
    instanceConfig     = local.instance_config

    images = {
      # Overridden on every EKS install: the chart default is coredns/coredns:1.6.6.
      coredns = local.coredns_image
    }

    saturnComponents = {
      calico = {
        enabled = true
        values = {
          cloudProvider = "aws"
          ipv4PoolCidr  = var.calico_ipv4_pool_cidr
        }
      }

      coredns = {
        enabled = true
        values = {
          clusterName  = local.cluster_name
          clusterDNSIP = local.dns_service_ip
          aws          = { region = var.region }
        }
      }

      clusterAutoscaler = {
        enabled = true
        values = {
          clusterName = local.cluster_name
          aws         = { useStaticInstanceList = false }
        }
      }

      clusterSetup = {
        enabled = true
        values = {
          aws = { zones = local.azs }
          dockerSecrets = {
            enabled          = true
            targetNamespaces = "cert-manager,default,ingress,kube-node-lease,kube-public,kube-system,logging,main-namespace,monitoring,saturn"
            # docker-secrets-manager reads ECR through the Atlas role (IRSA),
            # one of the three service accounts that role trusts.
            serviceAccountAnnotations = { "eks.amazonaws.com/role-arn" = module.cluster.atlas_role_arn }
            ecrPrivateUseIRSA         = true
            ecrPrivateRegion          = var.region
          }
        }
      }

      logging = {
        enabled = true
        values = {
          clusterName     = local.cluster_name
          aws             = { s3Bucket = local.saturn_bucket_name, region = var.region }
          atlasIAMRoleArn = module.cluster.atlas_role_arn
        }
      }

      traefik = {
        enabled = true
        values = {
          cloudProvider = "aws"
          aws = {
            acm        = aws_acm_certificate_validation.default.certificate_arn
            internalLB = false
            vpcCIDR    = var.vpc_cidr
            subnets    = local.public_subnet_ids
            s3Bucket   = local.saturn_bucket_name
          }
          loadBalancerCIDRs       = []
          loadBalancerIdleTimeout = 300
          certManager             = { enabled = false }
        }
      }

      sshProxy = {
        enabled = true
        values = {
          cloudProvider = "aws"
          aws = {
            internalLB = false
            subnets    = local.public_subnet_ids
          }
          loadBalancerCIDRs = []
          externalSshPort   = 22
        }
      }

      networkFilesystem = {
        enabled = var.network_filesystem_enabled
        values  = { aws = { region = var.region } }
      }

      atlas = {
        enabled = true
        values = {
          aws = {
            acm             = aws_acm_certificate_validation.default.certificate_arn
            internalLB      = false
            s3Bucket        = local.saturn_bucket_name
            region          = var.region
            atlasIAMRoleArn = module.cluster.atlas_role_arn
          }
          certManager = { enabled = false }
          env = {
            LOCAL_CLUSTER_NAME           = local.cluster_name
            WORKER_SECURITY_GROUP        = module.cluster.worker_security_group_id
            WORKER_SUBNET                = module.vpc.vpc_private_subnets[0]
            INTERNAL_LOADBALANCERS       = "False"
            SATURN_BUCKET_NAME           = local.saturn_bucket_name
            SATURN_IMAGE_METADATA_BUCKET = "saturn-image-metadata"
            NETWORK_FILESYSTEM_ENABLED   = var.network_filesystem_enabled ? "True" : "False"
            NETWORK_FILESYSTEM_EFS_ID    = module.cluster.saturn_nfs_efs_id
            OBJECT_STORAGE_ENABLED       = var.object_storage_enabled ? "True" : "False"
            # saturn-aws default. Set here so a chart default can never turn it on.
            ALLOW_DEPLOYMENT_PUBLIC_ACCESS = "False"
            # TLS is on the load balancer, so Atlas routes use no Traefik TLS store.
            LOCAL_CLUSTER_TLS_STORE = "none"
          }
        }
      }

      # Off, as on saturn-aws installs (ACM handles TLS). phoebe, spegel and
      # jobset are listed explicitly because the 2026.2.1-1xx charts fail to
      # render when those keys are missing.
      certManager    = { enabled = false }
      httpreqWebhook = { enabled = false }
      pandora        = { enabled = false }
      phoebe         = { enabled = false }
      spegel         = { enabled = false }
      jobset         = { enabled = false }
    }
  }
}

resource "helm_release" "saturn_operator" {
  count = var.manage_helm && var.start_nodes ? 1 : 0

  name             = "saturn-helm-operator"
  repository       = "oci://ghcr.io/saturncloud/charts"
  chart            = "saturn-helm-operator"
  version          = var.helm_chart_version
  namespace        = "saturn-system"
  create_namespace = true

  values = [yamlencode(local.saturn_helm_values)]

  # module.vpc: on destroy the NAT gateway must outlive the operator, because
  # the operator and the EBS CSI driver reach AWS and the manager through it.
  depends_on = [
    module.vpc,
    module.cluster,
    aws_eks_addon.ebs_csi,
    terraform_data.calico,
    terraform_data.coredns,
  ]
}

# Runs before the operator is uninstalled on destroy: removes everything that
# made AWS resources Terraform does not track (load balancers from Services,
# EBS volumes from PVCs), while nodes and the operator are still up.
resource "terraform_data" "pre_destroy_cleanup" {
  count = var.manage_helm && var.start_nodes ? 1 : 0

  input = {
    cluster_name = local.cluster_name
    region       = var.region
    script       = "${path.module}/scripts/pre-destroy-cleanup.sh"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${self.input.script} ${self.input.cluster_name} ${self.input.region}"
  }

  # Destroyed before the operator and before anything in the VPC. Without
  # module.vpc here, Terraform deleted the NAT gateway while this cleanup ran,
  # the EBS CSI driver lost its route to STS, and the volumes stayed attached.
  depends_on = [helm_release.saturn_operator, module.vpc]
}

output "saturn_helm_values_yaml" {
  description = "The values passed to the saturn-helm-operator chart. Contains the bootstrap token."
  value       = yamlencode(local.saturn_helm_values)
  sensitive   = true
}
