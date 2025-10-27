# --- Node service account (unchanged) ---
resource "nebius_iam_v1_service_account" "ncr_nodes" {
  parent_id   = var.project_id
  name        = "${var.cluster_name}-ncr-nodes"
  description = "Node-group SA for pulling from Nebius Container Registry"
}

# --- Lookup the built-in 'viewers' group in your tenant ---
# If your provider requires tenant scoping, add: parent_id = var.tenant_id
data "nebius_iam_v1_group" "viewers" {
  id = var.viewers_group_id
}

# --- Add the SA to the viewers group ---
resource "nebius_iam_v1_group_membership" "sa_in_viewers" {
  parent_id = data.nebius_iam_v1_group.viewers.id
  member_id = nebius_iam_v1_service_account.ncr_nodes.id
}


############################
# Your cluster
############################
resource "nebius_mk8s_v1_cluster" "saturn_cluster" {
  name      = var.cluster_name
  parent_id = var.project_id

  control_plane = {
    subnet_id = var.subnet_id
    endpoints = {
      public_endpoint = {}
    }
    etcd_cluster_size = 1
    version           = "1.30"
  }
}

############################
# GPU Clusters with InfiniBand
############################

# H100 GPU Cluster - uses configurable fabric (default: fabric-6)
resource "nebius_compute_v1_gpu_cluster" "gpu_cluster_h100" {
  name              = "${var.cluster_name}-gpu-h100-${var.h100_infiniband_fabric}"
  parent_id         = var.project_id
  infiniband_fabric = var.h100_infiniband_fabric
}

# H200 GPU Cluster - always uses fabric-7
resource "nebius_compute_v1_gpu_cluster" "gpu_cluster_h200" {
  name              = "${var.cluster_name}-gpu-h200-fabric-7"
  parent_id         = var.project_id
  infiniband_fabric = "fabric-7"
}

############################
# Node groups
############################

resource "nebius_mk8s_v1_node_group" "system_nodes" {
  parent_id = nebius_mk8s_v1_cluster.saturn_cluster.id
  name      = "system_node"

  labels = {
    "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "system"
  }

  template = {
    service_account_id = nebius_iam_v1_service_account.ncr_nodes.id

    metadata = {
      labels = {
        "node.saturncloud.io/role" = "system"
      }
    }
    boot_disk = {
      size_gibibytes = 93
      type           = "NETWORK_SSD_NON_REPLICATED"
    }
    resources = {
      platform = "cpu-d3"
      preset   = "4vcpu-16gb"
    }
  }

  autoscaling = {
    min_node_count = 2
    max_node_count = 100
  }
}

############################
# H100 GPU Node Groups
############################

resource "nebius_mk8s_v1_node_group" "gpu_h100_sxm_1gpu_20vcpu_160gb" {
  parent_id = nebius_mk8s_v1_cluster.saturn_cluster.id
  name      = "gpu-h100-sxm-1gpu-20vcpu-160gb"

  labels = {
    "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "gpu-h100-sxm-1gpu-20vcpu-160gb"
  }

  template = {
    service_account_id = nebius_iam_v1_service_account.ncr_nodes.id

    metadata = {
      labels = {
        "node.saturncloud.io/role" = "gpu-h100-sxm-1gpu-20vcpu-160gb"
        "nvidia.com/gpu"           = "1"
      }
    }
    boot_disk = {
      size_gibibytes = 93
      type           = "NETWORK_SSD_NON_REPLICATED"
    }
    resources = {
      platform = "gpu-h100-sxm"
      preset   = "1gpu-20vcpu-160gb"
    }
    gpu_settings = {
      drivers_preset = "cuda12"
    }
  }

  autoscaling = {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "nebius_mk8s_v1_node_group" "gpu_h100_sxm_8gpu_160vcpu_1280gb" {
  parent_id = nebius_mk8s_v1_cluster.saturn_cluster.id
  name      = "gpu-h100-sxm-8gpu-160vcpu-1280gb"

  labels = {
    "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "gpu-h100-sxm-8gpu-160vcpu-1280gb"
  }

  template = {
    service_account_id = nebius_iam_v1_service_account.ncr_nodes.id

    metadata = {
      labels = {
        "node.saturncloud.io/role" = "gpu-h100-sxm-8gpu-160vcpu-1280gb"
        "nvidia.com/gpu"           = "8"
      }
    }
    boot_disk = {
      size_gibibytes = 93
      type           = "NETWORK_SSD_NON_REPLICATED"
    }
    resources = {
      platform = "gpu-h100-sxm"
      preset   = "8gpu-160vcpu-1280gb"
    }
    gpu_cluster = {
      id = nebius_compute_v1_gpu_cluster.gpu_cluster_h100.id
    }
    gpu_settings = {
      drivers_preset = "cuda12"
    }
  }

  autoscaling = {
    min_node_count = 0
    max_node_count = 100
  }
}

############################
# H200 GPU Node Groups
############################

resource "nebius_mk8s_v1_node_group" "gpu_h200_sxm_1gpu_26vcpu_220gb" {
  parent_id = nebius_mk8s_v1_cluster.saturn_cluster.id
  name      = "gpu-h200-sxm-1gpu-26vcpu-220gb"

  labels = {
    "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "gpu-h200-sxm-1gpu-26vcpu-220gb"
  }

  template = {
    service_account_id = nebius_iam_v1_service_account.ncr_nodes.id

    metadata = {
      labels = {
        "node.saturncloud.io/role" = "gpu-h200-sxm-1gpu-26vcpu-220gb"
        "nvidia.com/gpu"           = "1"
      }
    }
    boot_disk = {
      size_gibibytes = 93
      type           = "NETWORK_SSD_NON_REPLICATED"
    }
    resources = {
      platform = "gpu-h200-sxm"
      preset   = "1gpu-26vcpu-220gb"
    }
    gpu_settings = {
      drivers_preset = "cuda12"
    }
  }

  autoscaling = {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "nebius_mk8s_v1_node_group" "gpu_h200_sxm_8gpu_208vcpu_1760gb" {
  parent_id = nebius_mk8s_v1_cluster.saturn_cluster.id
  name      = "gpu-h200-sxm-8gpu-208vcpu-1760gb"

  labels = {
    "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "gpu-h200-sxm-8gpu-208vcpu-1760gb"
  }

  template = {
    service_account_id = nebius_iam_v1_service_account.ncr_nodes.id

    metadata = {
      labels = {
        "node.saturncloud.io/role" = "gpu-h200-sxm-8gpu-208vcpu-1760gb"
        "nvidia.com/gpu"           = "8"
      }
    }
    boot_disk = {
      size_gibibytes = 93
      type           = "NETWORK_SSD_NON_REPLICATED"
    }
    resources = {
      platform = "gpu-h200-sxm"
      preset   = "8gpu-208vcpu-1760gb"
    }
    gpu_cluster = {
      id = nebius_compute_v1_gpu_cluster.gpu_cluster_h200.id
    }
    gpu_settings = {
      drivers_preset = "cuda12"
    }
  }

  autoscaling = {
    min_node_count = 0
    max_node_count = 100
  }
}
