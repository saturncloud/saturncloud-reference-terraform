
locals {
  my_ssh_public_key = file(var.ssh_key_path)
  # Changing the worker count will modify the nodepool in-place
  # Requesting more workers will scale the nodepool until the new desired count is reached
  # Note that requesting fewer workers will not delete existing VMs - they must be deleted manually
  kubeconfig_path = "./kubeconfig.yaml"
}

resource "crusoe_kubernetes_cluster" "my_cluster" {
  name = var.cluster_name
  # Set the desired CMK control plane version
  # See `crusoe kubernetes versions list` for available versions
  version  = var.kubernetes_version
  location = var.location

  # Optional: Set cluster/service CIDRs and node CIDR mask size
  # cluster_cidr = "192.168.1.0/24"
  # node_cidr_mask_size = "27"
  # service_cluster_ip_range = "192.168.2.0/24"

  # Optional: Add additional add-ons
  # See `crusoe kubernetes clusters create --help` for available add-ons
  add_ons = var.cluster_addons
}

resource "crusoe_kubernetes_node_pool" "system_nodepool" {
  name           = "system-nodes"
  cluster_id     = crusoe_kubernetes_cluster.my_cluster.id
  instance_count = 1
  type           = var.system_node_type
  # Optional: Add your SSH public key to the created nodes to allow SSH access
  ssh_key = local.my_ssh_public_key


  requested_node_labels = {
    "node.saturncloud.io/role" = "system"
    # "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "system"
  }

  lifecycle {
    ignore_changes = [
      ssh_key,
      instance_count
    ]
  }
}

resource "crusoe_kubernetes_node_pool" "c1a_4x_nodepool" {
  name           = "c1a-4x-nodes"
  cluster_id     = crusoe_kubernetes_cluster.my_cluster.id
  instance_count = 1
  type           = "c1a.4x"
  # Optional: Add your SSH public key to the created nodes to allow SSH access
  ssh_key = local.my_ssh_public_key


  requested_node_labels = {
    "node.saturncloud.io/role" = "crusoe-c1a-4x"
    # "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "crusoe-c1a-4x"
  }

  lifecycle {
    ignore_changes = [
      ssh_key,
      instance_count
    ]
  }
}

resource "crusoe_kubernetes_node_pool" "a100_80gb_1x" {
  name           = "a100-80gb-1x"
  cluster_id     = crusoe_kubernetes_cluster.my_cluster.id
  type           = "a100-80gb.1x"
  ssh_key        = local.my_ssh_public_key
  instance_count = 1

  requested_node_labels = {
    "node.saturncloud.io/role" = "crusoe-a100-80gb-1x"
    # "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "crusoe-a100-80gb-1x"
  }

  lifecycle {
    ignore_changes = [
      ssh_key,
      instance_count
    ]
  }
}


resource "crusoe_kubeconfig" "my_cluster_kubeconfig" {
  cluster_id = crusoe_kubernetes_cluster.my_cluster.id
}

output "cluster" {
  value = crusoe_kubernetes_cluster.my_cluster
}

