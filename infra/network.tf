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

# Pod network routes for cross-node pod communication
# Route traffic for node-0's pod subnet (10.200.0.0/24) to node-0
resource "google_compute_route" "pod_route_node_0" {
  name        = "pod-route-node-0"
  dest_range  = "10.200.0.0/24"
  network     = google_compute_network.kubernetes.name
  next_hop_ip = "10.240.0.20"  # node-0 internal IP
  priority    = 1000
}

# Route traffic for node-1's pod subnet (10.200.1.0/24) to node-1
resource "google_compute_route" "pod_route_node_1" {
  name        = "pod-route-node-1"
  dest_range  = "10.200.1.0/24"
  network     = google_compute_network.kubernetes.name
  next_hop_ip = "10.240.0.21"  # node-1 internal IP
  priority    = 1000
}
