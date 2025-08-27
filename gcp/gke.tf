resource "google_container_cluster" "primary" {
  name    = var.cluster_name
  project = var.project_id

  location = var.regional_cluster ? var.region : var.zone

  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = google_compute_network.vpc_network.name
  subnetwork               = google_compute_subnetwork.subnetwork.name
  deletion_protection      = false
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }
  cluster_autoscaling {
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    # The name of this attribute is very misleading, it controls node
    # autoprovisioning (NAP), not autoscaling.
    enabled = false
  }
  network_policy {
    # Enabling NetworkPolicy for clusters with DatapathProvider=ADVANCED_DATAPATH
    # is not allowed. Dataplane V2 will take care of network policy enforcement
    # instead.
    enabled = true
    # GKE Dataplane V2 support. This must be set to PROVIDER_UNSPECIFIED in
    # order to let the datapath_provider take effect.
    # https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/issues/656#issuecomment-720398658
  }

  addons_config {
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Enable shielded nodes to meet go/gke-cluster-pattern#req1.1.5
  enable_shielded_nodes = true
}

resource "google_container_node_pool" "system" {
  name     = "system"
  project  = var.project_id
  cluster  = google_container_cluster.primary.name
  location = google_container_cluster.primary.location
  node_config {
    machine_type    = "n2-highmem-2"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "system"
    }
  }
  autoscaling {
    min_node_count = 2
    max_node_count = 100
  }
}

# CPU Node Pools - General Purpose N2 Standard
resource "google_container_node_pool" "cpu_n2_standard_2" {
  name               = "cpu-n2-standard-2"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n2-standard-2"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "n2-standard-2"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "google_container_node_pool" "cpu_n2_standard_4" {
  name               = "cpu-n2-standard-4"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n2-standard-4"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "n2-standard-4"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "google_container_node_pool" "cpu_n2_standard_8" {
  name               = "cpu-n2-standard-8"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n2-standard-8"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "n2-standard-8"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "google_container_node_pool" "cpu_n2_standard_16" {
  name               = "cpu-n2-standard-16"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n2-standard-16"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "n2-standard-16"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "google_container_node_pool" "cpu_n2_standard_32" {
  name               = "cpu-n2-standard-32"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n2-standard-32"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "n2-standard-32"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

# CPU Node Pools - High Memory N2
resource "google_container_node_pool" "cpu_n2_highmem_4" {
  name               = "cpu-n2-highmem-4"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n2-highmem-4"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "n2-highmem-4"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "google_container_node_pool" "cpu_n2_highmem_8" {
  name               = "cpu-n2-highmem-8"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n2-highmem-8"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "n2-highmem-8"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "google_container_node_pool" "cpu_n2_highmem_16" {
  name               = "cpu-n2-highmem-16"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n2-highmem-16"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "n2-highmem-16"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "google_container_node_pool" "cpu_n2_highmem_32" {
  name               = "cpu-n2-highmem-32"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n2-highmem-32"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "n2-highmem-32"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

# CPU Node Pools - Compute Optimized C2
resource "google_container_node_pool" "cpu_c2_standard_4" {
  name               = "cpu-c2-standard-4"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "c2-standard-4"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "c2-standard-4"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "google_container_node_pool" "cpu_c2_standard_8" {
  name               = "cpu-c2-standard-8"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "c2-standard-8"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "c2-standard-8"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "google_container_node_pool" "cpu_c2_standard_16" {
  name               = "cpu-c2-standard-16"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "c2-standard-16"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "c2-standard-16"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "google_container_node_pool" "cpu_c2_standard_30" {
  name               = "cpu-c2-standard-30"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "c2-standard-30"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "c2-standard-30"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

resource "google_container_node_pool" "cpu_c2_standard_60" {
  name               = "cpu-c2-standard-60"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "c2-standard-60"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "c2-standard-60"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 100
  }
}

# CPU Node Pools - Memory Optimized M1/M2
resource "google_container_node_pool" "cpu_m1_megamem_96" {
  name               = "cpu-m1-megamem-96"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "m1-megamem-96"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "m1-megamem-96"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "cpu_m1_ultramem_40" {
  name               = "cpu-m1-ultramem-40"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "m1-ultramem-40"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "m1-ultramem-40"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "cpu_m1_ultramem_80" {
  name               = "cpu-m1-ultramem-80"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "m1-ultramem-80"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "m1-ultramem-80"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "cpu_m1_ultramem_160" {
  name               = "cpu-m1-ultramem-160"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "m1-ultramem-160"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "m1-ultramem-160"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "cpu_m2_ultramem_208" {
  name               = "cpu-m2-ultramem-208"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "m2-ultramem-208"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "m2-ultramem-208"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "cpu_n2_highmem_64" {
  name               = "cpu-n2-highmem-64"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n2-highmem-64"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role" = "n2-highmem-64"
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

# GPU Node Pools - NVIDIA L4 (G2 Series)
resource "google_container_node_pool" "gpu_g2_standard_4" {
  name               = "gpu-g2-standard-4"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "g2-standard-4"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "g2-standard-4"
      "node.saturncloud.io/accelerator" = "nvidia-l4"
    }
    guest_accelerator {
      type  = "nvidia-l4"
      count = 1
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "gpu_g2_standard_8" {
  name               = "gpu-g2-standard-8"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "g2-standard-8"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "g2-standard-8"
      "node.saturncloud.io/accelerator" = "nvidia-l4"
    }
    guest_accelerator {
      type  = "nvidia-l4"
      count = 1
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "gpu_g2_standard_12" {
  name               = "gpu-g2-standard-12"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "g2-standard-12"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "g2-standard-12"
      "node.saturncloud.io/accelerator" = "nvidia-l4"
    }
    guest_accelerator {
      type  = "nvidia-l4"
      count = 1
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "gpu_g2_standard_16" {
  name               = "gpu-g2-standard-16"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "g2-standard-16"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "g2-standard-16"
      "node.saturncloud.io/accelerator" = "nvidia-l4"
    }
    guest_accelerator {
      type  = "nvidia-l4"
      count = 1
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "gpu_g2_standard_24" {
  name               = "gpu-g2-standard-24"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "g2-standard-24"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "g2-standard-24"
      "node.saturncloud.io/accelerator" = "nvidia-l4"
    }
    guest_accelerator {
      type  = "nvidia-l4"
      count = 2
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "gpu_g2_standard_32" {
  name               = "gpu-g2-standard-32"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "g2-standard-32"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "g2-standard-32"
      "node.saturncloud.io/accelerator" = "nvidia-l4"
    }
    guest_accelerator {
      type  = "nvidia-l4"
      count = 2
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "gpu_g2_standard_48" {
  name               = "gpu-g2-standard-48"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "g2-standard-48"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "g2-standard-48"
      "node.saturncloud.io/accelerator" = "nvidia-l4"
    }
    guest_accelerator {
      type  = "nvidia-l4"
      count = 4
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "gpu_g2_standard_96" {
  name               = "gpu-g2-standard-96"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "g2-standard-96"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "g2-standard-96"
      "node.saturncloud.io/accelerator" = "nvidia-l4"
    }
    guest_accelerator {
      type  = "nvidia-l4"
      count = 8
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

# GPU Node Pools - NVIDIA T4
resource "google_container_node_pool" "gpu_n1_standard_4_t4" {
  name               = "gpu-n1-standard-4-t4"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n1-standard-4"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "n1-standard-4-t4"
      "node.saturncloud.io/accelerator" = "nvidia-tesla-t4"
    }
    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 1
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "gpu_n1_standard_8_t4" {
  name               = "gpu-n1-standard-8-t4"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n1-standard-8"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "n1-standard-8-t4"
      "node.saturncloud.io/accelerator" = "nvidia-tesla-t4"
    }
    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 1
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "gpu_n1_standard_16_t4" {
  name               = "gpu-n1-standard-16-t4"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n1-standard-16"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "n1-standard-16-t4"
      "node.saturncloud.io/accelerator" = "nvidia-tesla-t4"
    }
    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 2
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

resource "google_container_node_pool" "gpu_n1_standard_32_t4" {
  name               = "gpu-n1-standard-32-t4"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n1-standard-32"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "n1-standard-32-t4"
      "node.saturncloud.io/accelerator" = "nvidia-tesla-t4"
    }
    guest_accelerator {
      type  = "nvidia-tesla-t4"
      count = 4
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 50
  }
}

# GPU Node Pools - NVIDIA A100 (A2 Series)
resource "google_container_node_pool" "gpu_a2_highgpu_1g" {
  name               = "gpu-a2-highgpu-1g"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "a2-highgpu-1g"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "a2-highgpu-1g"
      "node.saturncloud.io/accelerator" = "nvidia-tesla-a100"
    }
    guest_accelerator {
      type  = "nvidia-tesla-a100"
      count = 1
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 20
  }
}

resource "google_container_node_pool" "gpu_a2_highgpu_2g" {
  name               = "gpu-a2-highgpu-2g"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "a2-highgpu-2g"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "a2-highgpu-2g"
      "node.saturncloud.io/accelerator" = "nvidia-tesla-a100"
    }
    guest_accelerator {
      type  = "nvidia-tesla-a100"
      count = 2
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 20
  }
}

resource "google_container_node_pool" "gpu_a2_highgpu_4g" {
  name               = "gpu-a2-highgpu-4g"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "a2-highgpu-4g"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "a2-highgpu-4g"
      "node.saturncloud.io/accelerator" = "nvidia-tesla-a100"
    }
    guest_accelerator {
      type  = "nvidia-tesla-a100"
      count = 4
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 20
  }
}

resource "google_container_node_pool" "gpu_a2_highgpu_8g" {
  name               = "gpu-a2-highgpu-8g"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "a2-highgpu-8g"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "a2-highgpu-8g"
      "node.saturncloud.io/accelerator" = "nvidia-tesla-a100"
    }
    guest_accelerator {
      type  = "nvidia-tesla-a100"
      count = 8
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 10
  }
}

resource "google_container_node_pool" "gpu_a2_megagpu_16g" {
  name               = "gpu-a2-megagpu-16g"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "a2-megagpu-16g"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "a2-megagpu-16g"
      "node.saturncloud.io/accelerator" = "nvidia-tesla-a100"
    }
    guest_accelerator {
      type  = "nvidia-tesla-a100"
      count = 16
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 5
  }
}

resource "google_container_node_pool" "gpu_a2_ultragpu_1g" {
  name               = "gpu-a2-ultragpu-1g"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "a2-ultragpu-1g"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "a2-ultragpu-1g"
      "node.saturncloud.io/accelerator" = "nvidia-a100-80gb"
    }
    guest_accelerator {
      type  = "nvidia-a100-80gb"
      count = 1
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 20
  }
}

resource "google_container_node_pool" "gpu_a2_ultragpu_2g" {
  name               = "gpu-a2-ultragpu-2g"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "a2-ultragpu-2g"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "a2-ultragpu-2g"
      "node.saturncloud.io/accelerator" = "nvidia-a100-80gb"
    }
    guest_accelerator {
      type  = "nvidia-a100-80gb"
      count = 2
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 20
  }
}

resource "google_container_node_pool" "gpu_a2_ultragpu_4g" {
  name               = "gpu-a2-ultragpu-4g"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "a2-ultragpu-4g"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "a2-ultragpu-4g"
      "node.saturncloud.io/accelerator" = "nvidia-a100-80gb"
    }
    guest_accelerator {
      type  = "nvidia-a100-80gb"
      count = 4
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 20
  }
}

resource "google_container_node_pool" "gpu_a2_ultragpu_8g" {
  name               = "gpu-a2-ultragpu-8g"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "a2-ultragpu-8g"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "a2-ultragpu-8g"
      "node.saturncloud.io/accelerator" = "nvidia-a100-80gb"
    }
    guest_accelerator {
      type  = "nvidia-a100-80gb"
      count = 8
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 10
  }
}

# GPU Node Pools - NVIDIA V100 (Legacy)
resource "google_container_node_pool" "gpu_n1_standard_8_v100" {
  name               = "gpu-n1-standard-8-v100"
  project            = var.project_id
  cluster            = google_container_cluster.primary.name
  location           = google_container_cluster.primary.location
  initial_node_count = 0
  node_config {
    machine_type    = "n1-standard-8"
    service_account = "default"
    oauth_scopes    = ["cloud-platform"]
    disk_size_gb    = 200
    labels = {
      "node.saturncloud.io/role"        = "n1-standard-8-v100"
      "node.saturncloud.io/accelerator" = "nvidia-tesla-v100"
    }
    guest_accelerator {
      type  = "nvidia-tesla-v100"
      count = 1
    }
  }
  autoscaling {
    min_node_count = 0
    max_node_count = 30
  }
}

