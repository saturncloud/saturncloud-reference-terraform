# Crusoe Managed Kubernetes Cluster with A100 GPUs

This Terraform configuration creates a **Crusoe Managed Kubernetes (CMK)** cluster with A100 GPU support, leveraging Crusoe's fully managed control plane and node pools.

## Prerequisites

1. **Crusoe Cloud Account**: Sign up at https://console.crusoecloud.com/
2. **API Keys**: Create API keys from the Crusoe console at https://console.crusoecloud.com/security/tokens
3. **SSH Key**: Ensure you have an SSH key pair for accessing the nodes
4. **Terraform**: Install Terraform >= 1.0
5. **kubectl**: Install kubectl for managing the cluster

## Configuration

### 1. Configure Crusoe Credentials

Add your Crusoe credentials to `~/.crusoe/config`:

```
[default]
access_key_id="YOUR_ACCESS_KEY"
secret_key="YOUR_SECRET_KEY"
```

### 2. Update Variables

Edit `terraform.tfvars` to match your requirements:

```hcl
cluster_name       = "saturn-cluster-crusoe"
project_id         = "your-crusoe-project-id"
location           = "us-east1-a"
ssh_key_path       = "~/.ssh/id_rsa.pub"
kubernetes_version = "1.30"

# System nodes (always running)
system_node_count = 2

# Scale other node pools as needed
a100_1x_node_count = 1  # Start with 1 A100 node
```

### 3. Configure Backend (Optional)

Update the S3 backend configuration in `terraform.tf` if you want to use remote state:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "crusoe/k8s-cluster.tfstate"
    region = "us-east-1"
  }
}
```

## Deployment

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Plan the Deployment

```bash
terraform plan
```

### 3. Apply the Configuration

```bash
terraform apply
```

## Cluster Architecture

The cluster uses **Crusoe Managed Kubernetes (CMK)** with:

- **Managed Control Plane**: Crusoe manages the API server, etcd, and controller manager
- **System Node Pool**: 2 nodes for running cluster services (always running)
- **CPU Node Pools**: Various CPU-only node pools (scale as needed)
- **GPU Node Pools**: A100 GPU node pools:
  - 1x A100 80GB GPU nodes
  - 2x A100 80GB GPU nodes  
  - 4x A100 80GB GPU nodes
  - 8x A100 80GB GPU nodes

## Node Labels

All nodes are automatically labeled with:
- `node.saturncloud.io/role=<role>` (system, crusoe-large, crusoe-1xa100, etc.)
- `node-role.kubernetes.io/worker=true`

GPU nodes also have:
- `nvidia.com/gpu=<count>` (1, 2, 4, or 8)
- `nvidia.com/gpu.product=A100-SXM4-80GB`

## Accessing the Cluster

After deployment, a kubeconfig file is automatically generated:

```bash
# Use the generated kubeconfig
export KUBECONFIG=./kubeconfig-saturn-cluster-crusoe.yaml
kubectl get nodes
```

Or copy the kubeconfig to your default location:

```bash
cp ./kubeconfig-saturn-cluster-crusoe.yaml ~/.kube/config
kubectl get nodes
```

## Cluster Add-ons

The cluster automatically includes:
- **GPU Operator**: For managing NVIDIA GPU resources
- **Cluster Autoscaler**: For automatically scaling node pools based on demand

## Scaling Node Pools

You can scale node pools by updating the terraform.tfvars file:

```hcl
# Scale up A100 1x nodes
a100_1x_node_count = 5

# Scale up CPU nodes
cpu_large_node_count = 3
```

Then apply the changes:

```bash
terraform apply
```

## GPU Workloads

Schedule GPU workloads using node selectors:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  containers:
  - name: gpu-container
    image: nvidia/cuda:11.0-base
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
  nodeSelector:
    node.saturncloud.io/role: crusoe-1xa100
```

## Monitoring and Management

- **Cluster Uptime**: Up to 99.98% availability
- **Support**: Enterprise-grade support with 6-minute average response time
- **Monitoring**: Built-in monitoring and performance insights

## Cleanup

To destroy the cluster:

```bash
terraform destroy
```

## Advantages of Managed Kubernetes

- **No Control Plane Management**: Crusoe handles all control plane operations
- **Automatic Updates**: Managed updates for Kubernetes components
- **High Availability**: Built-in HA for the control plane
- **Simplified Operations**: Focus on workloads, not infrastructure
- **Enterprise Support**: 24/7 support from Crusoe's team

## Troubleshooting

### Common Issues

1. **Authentication**: Verify your Crusoe credentials in `~/.crusoe/config`
2. **Node Scaling**: Check the Terraform outputs for node pool status
3. **GPU Access**: Ensure GPU operator is installed and pods have proper resource requests

### Getting Help

- Check cluster status: `kubectl get nodes -o wide`
- View node pool details: `terraform output node_pools`
- Access logs: `kubectl logs -n gpu-operator <pod-name>`

## Cost Optimization

- Start with minimal node counts (most pools set to 0)
- Use cluster autoscaler to scale based on demand
- Monitor usage with `kubectl top nodes`
- Scale down unused node pools regularly