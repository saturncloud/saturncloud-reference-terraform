# --- Node service account (unchanged) ---
resource "nebius_iam_v1_service_account" "ncr_nodes" {
  parent_id   = var.project_id
  name        = "ncr-nodes"
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
    version = "1.30"
  }
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

resource "nebius_mk8s_v1_node_group" "cpu_large" {
  parent_id = nebius_mk8s_v1_cluster.saturn_cluster.id
  name      = "nebius-large"

  labels = {
    "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "nebius-large"
  }

  template = {
    service_account_id = nebius_iam_v1_service_account.ncr_nodes.id

    metadata = {
      labels = {
        "node.saturncloud.io/role" = "nebius-large"
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
    min_node_count = 0
    max_node_count = 100
  }
}

resource "nebius_mk8s_v1_node_group" "cpu_2xlarge" {
  parent_id = nebius_mk8s_v1_cluster.saturn_cluster.id
  name      = "nebius-2xlarge"

  labels = {
    "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "nebius-2xlarge"
  }

  template = {
    service_account_id = nebius_iam_v1_service_account.ncr_nodes.id

    metadata = {
      labels = {
        "node.saturncloud.io/role" = "nebius-2xlarge"
      }
    }
    boot_disk = {
      size_gibibytes = 93
      type           = "NETWORK_SSD_NON_REPLICATED"
    }
    resources = {
      platform = "cpu-d3"
      preset   = "16vcpu-64gb"
    }
  }

  autoscaling = {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "nebius_mk8s_v1_node_group" "cpu_4xlarge" {
  parent_id = nebius_mk8s_v1_cluster.saturn_cluster.id
  name      = "nebius-4xlarge"

  labels = {
    "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "nebius-4xlarge"
  }

  template = {
    service_account_id = nebius_iam_v1_service_account.ncr_nodes.id

    metadata = {
      labels = {
        "node.saturncloud.io/role" = "nebius-4xlarge"
      }
    }
    boot_disk = {
      size_gibibytes = 93
      type           = "NETWORK_SSD_NON_REPLICATED"
    }
    resources = {
      platform = "cpu-d3"
      preset   = "64vcpu-256gb"
    }
  }

  autoscaling = {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "nebius_mk8s_v1_node_group" "h200x1" {
  parent_id = nebius_mk8s_v1_cluster.saturn_cluster.id
  name      = "1xh200"

  labels = {
    "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "nebius-1xh200"
  }

  template = {
    service_account_id = nebius_iam_v1_service_account.ncr_nodes.id

    metadata = {
      labels = {
        "node.saturncloud.io/role"         = "nebius-1xh200"
        "nvidia.com/gpu"                   = "1"
      }
    }
    boot_disk = {
      size_gibibytes = 93
      type           = "NETWORK_SSD_NON_REPLICATED"
    }
    resources = {
      platform = "gpu-h200-sxm"
      preset   = "1gpu-16vcpu-200gb"
    }
    gpu_settings = null
  }

  autoscaling = {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "nebius_mk8s_v1_node_group" "h200x8" {
  parent_id = nebius_mk8s_v1_cluster.saturn_cluster.id
  name      = "8xh200"

  labels = {
    "k8s.io/cluster-autoscaler/node-template/label/node.saturncloud.io/role" = "nebius-8xh200"
  }

  template = {
    service_account_id = nebius_iam_v1_service_account.ncr_nodes.id

    metadata = {
      labels = {
        "node.saturncloud.io/role"         = "nebius-8xh200"
        "nvidia.com/gpu"                   = "8"
      }
    }
    boot_disk = {
      size_gibibytes = 93
      type           = "NETWORK_SSD_NON_REPLICATED"
    }
    resources = {
      platform = "gpu-h200-sxm"
      preset   = "8gpu-128vcpu-1600gb"
    }
    gpu_settings = null
  }

  autoscaling = {
    min_node_count = 0
    max_node_count = 100
  }
}
