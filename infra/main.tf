# Startup script templates using built-in templatefile function
locals {
  common_setup_script = file("${path.module}/scripts/common-setup.sh")
  jumpbox_setup_script = file("${path.module}/scripts/jumpbox-setup.sh")
  controller_setup_script = file("${path.module}/scripts/controller-setup.sh")
  ca_tls_script = file("${path.module}/scripts/ca_tls.sh")
  
  # SSH keys configuration - just user key
  ssh_keys = "${var.ssh_user}:${file(pathexpand(var.public_key_path))}\nroot:${file(pathexpand(var.public_key_path))}"
  
}

resource "google_compute_address" "jumpbox_ip" {
  name         = "jumpbox-ip"
  region       = var.region
  address      = "10.240.0.9"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.kubernetes.name
}

resource "google_compute_address" "controller_ip" {
  name         = "controller-0-ip"
  region       = var.region
  address      = "10.240.0.10"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.kubernetes.name
}

resource "google_compute_address" "worker_ips" {
  count        = 2
  name         = "worker-${count.index}-ip"
  region       = var.region
  address      = "10.240.0.2${count.index}"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.kubernetes.name
}


resource "google_compute_instance" "jumpbox" {
  name         = "jumpbox"
  machine_type = var.worker_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size_gb
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.kubernetes.name
    access_config {} # <-- This gives the public IP
    network_ip = google_compute_address.jumpbox_ip.address
  }

  metadata = {
    ssh-keys = local.ssh_keys
    ca-tls-script = local.ca_tls_script
  }

  metadata_startup_script = "${local.common_setup_script}\n${local.jumpbox_setup_script}"

  tags = ["ssh", "jumpbox"]
}


resource "google_compute_instance" "controller" {
  count        = var.controller_count
  name         = "controller"
  machine_type = var.controller_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.kubernetes.id
    subnetwork = google_compute_subnetwork.kubernetes.name
    access_config {}
    network_ip = google_compute_address.controller_ip.address
  }

  metadata = {
    ssh-keys = local.ssh_keys
  }

  metadata_startup_script = "${local.common_setup_script}\n${local.controller_setup_script}"

  tags = ["kubernetes", "controller"]
}

resource "google_compute_instance" "worker" {
  count        = var.worker_count
  name         = "worker-${count.index}"
  machine_type = var.worker_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.kubernetes.id
    subnetwork = google_compute_subnetwork.kubernetes.name
    access_config {}
    network_ip = google_compute_address.worker_ips[count.index].address
  }

  metadata = {
    ssh-keys = local.ssh_keys
  }

  metadata_startup_script = "${local.common_setup_script}\n${templatefile("${path.module}/scripts/worker-setup.sh", { worker_index = count.index })}"

  tags = ["kubernetes", "worker"]
}
