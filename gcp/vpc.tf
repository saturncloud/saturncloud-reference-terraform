resource "google_compute_network" "vpc_network" {
  project                 = var.project_id
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  name          = "primary-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc_network.name
  ip_cidr_range = var.cidr
}