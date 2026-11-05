# Saturn Cloud configuration for Nebius
#
# Before running terraform, source environment.sh to set Nebius infrastructure variables:
#   source environment.sh

############################
# Saturn Cloud configuration
############################

cluster_name           = "saturn-cluster"
saturn_admin_email     = "admin@example.com"
saturn_customer_name   = "my-org"
saturn_bootstrap_token = ""

# The domain defaults to <saturn_customer_name>.saturnenterprise.io. Set saturn_domain only
# if Saturn Cloud has agreed a different domain with you.
# saturn_domain = "my-org.saturnenterprise.io"

# saturn-helm-operator chart version. This must stay set. Our chart versions look like
# pre-releases (2026.8.1-62), so Helm cannot choose a "latest" version and fails without it.
# 2026.8.1-62 is the version last installed from scratch on Nebius.
helm_chart_version = "2026.8.1-62"

############################
# Node pools
############################
# By default the node pools come from your region (NEBIUS_REGION): three cpu-d3 sizes and
# the 1-GPU size of each GPU platform the region offers. See region_gpu_node_pools in
# locals.tf for the list, and the regions that have defaults. Each pool scales from zero
# and becomes an instance size in Saturn Cloud.
#
# Set node_pools to choose your own pools instead, or to install in a region without
# defaults. To see what your project's region offers:
#   nebius compute platform list --parent-id "${NEBIUS_PROJECT_ID}"
# 8-GPU presets require infiniband_fabric (obtain from Nebius support).

# node_pools = [
#   { platform = "cpu-d3", preset = "4vcpu-16gb" },
#   { platform = "cpu-d3", preset = "16vcpu-64gb" },
#   { platform = "cpu-d3", preset = "64vcpu-256gb" },
#   { platform = "gpu-h200-sxm", preset = "1gpu-16vcpu-200gb" },
#   # 8-GPU, requires an InfiniBand fabric from Nebius support
#   { platform = "gpu-h200-sxm", preset = "8gpu-128vcpu-1600gb", infiniband_fabric = "fabric-7" },
# ]

############################
# Shared Filesystem (filestore)
############################
# A Nebius shared filesystem (ReadWriteMany) is created by default.
# Set enable_filestore = false to opt out.

# enable_filestore              = true   # Set to false to skip creating a shared filesystem
# existing_filestore            = ""     # Use an existing filestore ID, or leave empty to create a new one
# filestore_disk_size_gibibytes = 100    # Size of the shared filesystem in GiB (fixed, does not auto-expand)
