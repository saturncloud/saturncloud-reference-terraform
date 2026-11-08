# Saturn Cloud on AWS (EKS), without saturn-aws

This directory installs a new Saturn Cloud 2026.02.01 cluster on AWS with
Terraform alone. It replaces the Python orchestration in saturn-aws for new
installs. It does not change existing installs, which already run the Saturn
operator on their own EKS clusters.

The AWS resources come from saturn-aws's own Terraform, used unchanged:
`saturn-aws/acm`, `saturn-aws/vpc` and `saturn-aws/cluster` are verbatim copies
of `saturn_aws/templates/terraform/{acm,vpc,cluster}` from saturn-aws
`release-2026.02.01` (commit `12bb7bd`). The Terraform files in this directory
supply the values saturn-aws's Python used to template into those stacks, and do
the steps the Python did around them:

1. Delete the AWS VPC CNI while the cluster has no nodes.
2. Install Calico and CoreDNS from the charts in the operator image.
3. Create the kube-proxy and EBS CSI add-ons.
4. Install the Saturn operator, which installs everything else.

`~/work/saturn-architecture-docs/eks-fresh-install-cni-runbook.md` explains why
each step is needed and in what order.

## What it creates

- An ACM wildcard certificate for `*.<domain>`, validated through the Saturn
  manager, which writes the DNS record.
- A VPC with two public and two private subnets and one NAT gateway.
- An EKS cluster named `saturn-cluster-<org_name>`, with self-managed node
  groups: `system` (one r5.large), and an on-demand and a spot group for each
  entry in `instance_sizes`.
- The IAM roles, security groups and KMS key saturn-aws creates.
- The Saturn operator, in namespace `saturn-system`. It then installs Atlas,
  Traefik, the SSH proxy, logging, monitoring and the cluster autoscaler. AWS
  load balancers terminate TLS with the ACM certificate.

The `bucket/` stack creates the `saturn-<org_name>` bucket. It holds this stack's
Terraform state and Saturn's logs, as it does on saturn-aws installs.

## Before you start

You need:

- Terraform 1.5.7 to 1.9.x. saturn-aws uses 1.5.7. Terraform 1.13 rejects the
  cluster stack's aws-auth resource as a dependency cycle.
- The AWS CLI, kubectl, helm, jq and docker on the machine that runs Terraform.
- AWS credentials for the target account.
- A bootstrap token for the customer, from the Saturn manager. The operator
  spends it when it starts. The first apply already uses it, to have the
  manager write the certificate's validation record. A token for a different
  customer fails there with `manager /install/acme returned HTTP 403`.
- Network access from the machine that runs Terraform to the cluster's public
  API endpoint. The endpoint only accepts the manager's addresses, the NAT
  gateway and the CIDRs in `public_cluster_allow_list`, so add the machine's
  address there.

## Install

All commands run in this directory unless noted.

1. Create the bucket (local state, kept in `bucket/`):

   ```bash
   cd bucket
   terraform init
   terraform apply -var region=us-west-2 -var org_name=<org_name>
   cd ..
   ```

2. Copy the Calico and CoreDNS charts out of the operator image that matches
   `helm_chart_version` (chart `2026.2.1-147` is image tag `2026.02.01-147`):

   ```bash
   scripts/fetch-charts.sh 2026.02.01-147
   ```

3. Initialise the backend, using the key layout saturn-aws used:

   ```bash
   terraform init \
     -backend-config="bucket=saturn-<org_name>" \
     -backend-config="key=terraform/<org_name>/aws.tfstate" \
     -backend-config="region=us-west-2"
   ```

4. Write a tfvars file. The token never goes in it:

   ```hcl
   region                    = "us-west-2"
   org_name                  = "<org_name>"
   tags                      = { owner = "<you>" }
   public_cluster_allow_list = ["<your address>/32"]
   helm_chart_version        = "2026.2.1-147"
   saturn_customer_name      = "<customer>"
   saturn_admin_email        = "<admin email>"
   saturn_manager_uri        = "https://manager.aws.saturnenterprise.io"
   ```

5. First apply, with no nodes. This creates the certificate, the VPC and the
   cluster, deletes the AWS CNI, and installs Calico and CoreDNS:

   ```bash
   export TF_VAR_saturn_bootstrap_token="$(cat <file holding the token>)"
   terraform apply -var-file=<tfvars>
   ```

6. Second apply. This starts the system node, creates the add-ons and installs
   the operator:

   ```bash
   terraform apply -var-file=<tfvars> -var start_nodes=true
   ```

   Keep passing `-var start_nodes=true` on every later apply and on destroy.
   Without it, Terraform would scale the system node group to zero and remove
   the operator.

7. Wait for the site. The operator registers `*.<domain>` and `ssh.<domain>`
   with the manager within five minutes of the load balancers appearing. New
   Classic Load Balancers have taken up to 90 minutes to start answering (see
   the runbook's Gotchas).

## Destroy

```bash
terraform destroy -var-file=<tfvars> -var start_nodes=true
cd bucket && terraform destroy -var region=us-west-2 -var org_name=<org_name> -var force_destroy=true
```

Before the operator is removed, `scripts/pre-destroy-cleanup.sh` does three
things:

- It deletes the Saturn components and every LoadBalancer Service and
  PersistentVolumeClaim. Those own load balancers and EBS volumes that
  Terraform does not track.
- It waits for AWS to delete them.
- It stops the destroy if any are left. Run `terraform destroy` again to retry;
  it lists what was left and why.

## Left out

The following saturn-aws features are not in this module. Each would need its
own work and testing:

- Image mirrors and private registries (`image_mirror`).
- Private clusters and internal load balancers. `internalLB` is always false
  and the API endpoint mode is set with `cluster_accessibility`.
- Installing into an existing VPC (`skip_vpc`) and reusing an existing
  certificate (`acm_arn`).
- Customer-supplied IAM roles. The module always creates its own, as
  saturn-aws does by default.
- cert-manager, httpreq-webhook, Pandora, Phoebe, spegel and JobSet. They are
  disabled, as on saturn-aws installs.
- saturn-aws's upgrade and migration commands, and its copies of state files.

EFS (`network_filesystem_enabled`), object storage and GPU sizes are wired
through, but this module has not been tested with them.
