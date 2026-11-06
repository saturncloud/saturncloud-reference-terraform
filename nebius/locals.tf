locals {
  # Filestore
  filestore = {
    mount_tag  = "data"
    mount_path = var.filestore_mount_path
  }

  filesystem_csi_chart_name = "csi-mounted-fs-path"
  filesystem_csi_enabled    = local.shared_filesystem != null
  filesystem_csi_data_dir   = "${trimsuffix(local.filestore.mount_path, "/")}/csi-mounted-fs-path-data/"

  shared_filesystem = var.enable_filestore ? {
    id = try(
      one(nebius_compute_v1_filesystem.shared_filesystem).id,
      one(data.nebius_compute_v1_filesystem.shared_filesystem).id,
    )
    size_gibibytes = floor(provider::units::to_gib(try(
      one(nebius_compute_v1_filesystem.shared_filesystem).status.size_bytes,
      one(data.nebius_compute_v1_filesystem.shared_filesystem).status.size_bytes,
    )))
    mount_tag = local.filestore.mount_tag
  } : null

  ssh_public_key = var.ssh_public_key.key != null ? var.ssh_public_key.key : (
    try(fileexists(var.ssh_public_key.path), false) ? file(var.ssh_public_key.path) : null
  )

  # The domain defaults to <customer>.saturnenterprise.io, the domain Saturn Cloud manages
  # for each customer. base_url and ssh_domain follow from it.
  saturn_domain     = var.saturn_domain != "" ? var.saturn_domain : "${var.saturn_customer_name}.saturnenterprise.io"
  saturn_base_url   = "https://app.${local.saturn_domain}"
  saturn_ssh_domain = "ssh.${local.saturn_domain}"

  # Hardcoded constants
  saturn_cloud_provider = "nebius"

  default_cuda_preset = "cuda13.0"

  # ---------------------------------------------------------------------------
  # Default node pools for each region
  # ---------------------------------------------------------------------------
  # Each Nebius region offers different GPU platforms. When var.node_pools is not set,
  # the pools for var.region come from this table, and the instance sizes shown in Saturn
  # Cloud are built from the same pools below, so the two always match.
  # Every region gets the same three cpu-d3 sizes and the 1-GPU preset of each GPU
  # platform the region offers. 8-GPU presets need an InfiniBand fabric from Nebius
  # support, so they are left out. L40S is left out of eu-north1 because it is rarely
  # available. Platforms come from `nebius compute platform list` in each region.
  cpu_node_pools = [
    { platform = "cpu-d3", preset = "4vcpu-16gb" },
    { platform = "cpu-d3", preset = "16vcpu-64gb" },
    { platform = "cpu-d3", preset = "64vcpu-256gb" },
  ]
  region_gpu_node_pools = {
    eu-north1 = [
      { platform = "gpu-h200-sxm", preset = "1gpu-16vcpu-200gb" },
      { platform = "gpu-h100-sxm", preset = "1gpu-16vcpu-200gb" },
    ]
    eu-south1 = [
      { platform = "gpu-b300-sxm-a", preset = "1gpu-24vcpu-464gb" },
      { platform = "gpu-rtx6000-a", preset = "1gpu-24vcpu-218gb" },
    ]
    eu-west1 = [
      { platform = "gpu-h200-sxm", preset = "1gpu-16vcpu-200gb" },
    ]
    eu-west2 = [
      { platform = "gpu-b300-sxm", preset = "1gpu-24vcpu-346gb" },
    ]
    me-west1 = [
      { platform = "gpu-b200-sxm-a", preset = "1gpu-20vcpu-224gb" },
    ]
    uk-south1 = [
      { platform = "gpu-b300-sxm", preset = "1gpu-24vcpu-346gb" },
    ]
    uk-south2 = [
      { platform = "gpu-rtx6000-a", preset = "1gpu-24vcpu-218gb" },
    ]
    us-central1 = [
      { platform = "gpu-h200-sxm", preset = "1gpu-16vcpu-200gb" },
      { platform = "gpu-b200-sxm", preset = "1gpu-20vcpu-224gb" },
      { platform = "gpu-rtx6000", preset = "1gpu-24vcpu-218gb" },
    ]
    us-north1 = [
      { platform = "gpu-b300-sxm", preset = "1gpu-24vcpu-346gb" },
    ]
  }

  # var.node_pools replaces the region's defaults when it is set. Both sources are
  # normalised to the same object shape so the conditional below type-checks.
  override_node_pools = var.node_pools == null ? [] : [
    for pool in var.node_pools : {
      platform          = pool.platform
      preset            = pool.preset
      min_nodes         = pool.min_nodes
      max_nodes         = pool.max_nodes
      boot_disk_gb      = pool.boot_disk_gb
      infiniband_fabric = pool.infiniband_fabric
      drivers_preset    = pool.drivers_preset
    }
  ]
  region_node_pools = [
    for pool in concat(local.cpu_node_pools, lookup(local.region_gpu_node_pools, var.region, [])) : {
      platform          = pool.platform
      preset            = pool.preset
      min_nodes         = 0
      max_nodes         = 10
      boot_disk_gb      = 372
      infiniband_fabric = null
      drivers_preset    = null
    }
  ]
  node_pools = var.node_pools != null ? local.override_node_pools : local.region_node_pools

  # Build a node group key for each pool (used as for_each keys and node_role names)
  node_pool_keys = {
    for i, pool in local.node_pools : "${pool.platform}-${pool.preset}${pool.infiniband_fabric != null ? "-${pool.infiniband_fabric}" : ""}" => pool
  }

  # Image builds run on the smallest CPU pool. If a node_pools override leaves that pool
  # out, they run on the system nodes, which always exist.
  saturn_image_build_node_role = contains(keys(local.node_pool_keys), "cpu-d3-4vcpu-16gb") ? "cpu-d3-4vcpu-16gb" : "system"

  # Derive unique infiniband fabrics from node pools that have fabric set
  # Keyed by "${platform}-${fabric}" to ensure one gpu_cluster per platform+fabric combo
  infiniband_fabrics = {
    for key, pool in local.node_pool_keys : "${pool.platform}-${pool.infiniband_fabric}" => pool
    if pool.infiniband_fabric != null
  }

  # Identify first CPU and first GPU pools for defaults
  cpu_pools = [for pool in local.node_pools : pool if !startswith(pool.platform, "gpu-")]
  gpu_pools = [for pool in local.node_pools : pool if startswith(pool.platform, "gpu-")]

  default_cpu_name = length(local.cpu_pools) > 0 ? "nebius-${local.cpu_pools[0].platform}-${local.cpu_pools[0].preset}" : null
  default_gpu_name = length(local.gpu_pools) > 0 ? (
    local.gpu_pools[0].infiniband_fabric != null
    ? "nebius-${local.gpu_pools[0].platform}-${local.gpu_pools[0].preset}-${local.gpu_pools[0].infiniband_fabric}"
    : "nebius-${local.gpu_pools[0].platform}-${local.gpu_pools[0].preset}"
  ) : null

  # Build saturn_instance_config dynamically from node_pools + validation map
  instance_config = {
    default_cpu = local.default_cpu_name
    default_gpu = local.default_gpu_name
    sizes = [
      for key, pool in local.node_pool_keys : {
        name          = "nebius-${key}"
        cores         = local.valid_presets["${pool.platform}/${pool.preset}"].cores
        memory        = local.valid_presets["${pool.platform}/${pool.preset}"].memory
        gpu           = local.valid_presets["${pool.platform}/${pool.preset}"].gpus
        gpu_type      = local.valid_presets["${pool.platform}/${pool.preset}"].gpu_type
        hardware_type = local.valid_presets["${pool.platform}/${pool.preset}"].hardware_type
        display_name  = key
        node_role     = key
      }
    ]
  }

  # Clean instance config by removing null values from each size object
  # A CPU-only node_pools list has no default GPU. Send "" rather than null: the chart's own
  # default for this field is null, and Atlas crash-loops at startup if it receives null.
  cleaned_instance_config = {
    default_cpu = local.instance_config.default_cpu != null ? local.instance_config.default_cpu : ""
    default_gpu = local.instance_config.default_gpu != null ? local.instance_config.default_gpu : ""
    sizes = concat(
      [for size in local.instance_config.sizes : {
        for k, v in size : k => v if v != null
      }],
      [for size in var.extra_instance_sizes : {
        for k, v in size : k => v if v != null
      }]
    )
  }
}
