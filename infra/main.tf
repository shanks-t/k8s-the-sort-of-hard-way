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
  machine_type = var.machine_type
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
    ssh-keys = "${var.ssh_user}:${file(var.public_key_path)}"
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    
    # Enable root SSH access for Kubernetes The Hard Way tutorial
    # Find any existing PermitRootLogin setting (commented or not) and replace with 'yes'
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    # Restart SSH daemon to apply the new configuration
    systemctl restart sshd
    
    # Configure proper hostname for the jumpbox instance
    # Set the system hostname using hostnamectl
    hostnamectl set-hostname jumpbox
    # Update /etc/hosts to map localhost to the new hostname
    sed -i 's/^127.0.1.1.*/127.0.1.1\tjumpbox/' /etc/hosts
    # Restart hostname service to ensure changes take effect
    systemctl restart systemd-hostnamed
  EOF

  tags = ["ssh", "jumpbox"]
}


resource "google_compute_instance" "controller" {
  count        = var.controller_count
  name         = "controller"
  machine_type = var.machine_type
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
    ssh-keys = "${var.ssh_user}:${file(var.public_key_path)}"
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    
    # Enable root SSH access for Kubernetes The Hard Way tutorial
    # Find any existing PermitRootLogin setting (commented or not) and replace with 'yes'
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    # Restart SSH daemon to apply the new configuration
    systemctl restart sshd
    
    # Configure proper hostname for the controller instance
    # Set the system hostname using hostnamectl
    hostnamectl set-hostname controller
    # Update /etc/hosts to map localhost to the new hostname
    sed -i 's/^127.0.1.1.*/127.0.1.1\tcontroller/' /etc/hosts
    # Restart hostname service to ensure changes take effect
    systemctl restart systemd-hostnamed
  EOF

  tags = ["kubernetes", "controller"]
}

resource "google_compute_instance" "worker" {
  count        = var.worker_count
  name         = "worker-${count.index}"
  machine_type = var.machine_type
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
    ssh-keys = "${var.ssh_user}:${file(var.public_key_path)}"
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    
    # Enable root SSH access for Kubernetes The Hard Way tutorial
    # Find any existing PermitRootLogin setting (commented or not) and replace with 'yes'
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    # Restart SSH daemon to apply the new configuration
    systemctl restart sshd
    
    # Configure proper hostname for worker instance (worker-0, worker-1, etc.)
    # Set the system hostname using hostnamectl with Terraform count index
    hostnamectl set-hostname worker-${count.index}
    # Update /etc/hosts to map localhost to the new hostname
    sed -i 's/^127.0.1.1.*/127.0.1.1\tworker-${count.index}/' /etc/hosts
    # Restart hostname service to ensure changes take effect
    systemctl restart systemd-hostnamed
  EOF

  tags = ["kubernetes", "worker"]
}
