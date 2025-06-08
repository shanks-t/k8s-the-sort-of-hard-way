resource "google_compute_network" "kubernetes" {
  name                    = "kubernetes"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "kubernetes" {
  name          = "kubernetes"
  ip_cidr_range = "10.240.0.0/24"
  region        = var.region
  network       = google_compute_network.kubernetes.id
}

resource "google_compute_router" "k8s_router" {
  name    = "k8s-router"
  network = google_compute_network.kubernetes.id
  region  = var.region
}

resource "google_compute_router_nat" "k8s_nat" {
  name                               = "k8s-nat"
  router                             = google_compute_router.k8s_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
