resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_subnetwork.kubernetes.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["ssh"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_subnetwork.kubernetes.name

  allow {
    protocol = "all"
  }

  source_ranges = ["10.240.0.0/24"]

  target_tags = ["kubernetes", "controller", "worker"]
}

resource "google_compute_firewall" "allow_k8s_api" {
  name    = "allow-kubernetes-api"
  network = google_compute_subnetwork.kubernetes.name

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = ["10.240.0.0/24"]

  target_tags = ["controller"]
}

resource "google_compute_firewall" "allow_icmp" {
  name    = "allow-icmp"
  network = google_compute_subnetwork.kubernetes.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}
