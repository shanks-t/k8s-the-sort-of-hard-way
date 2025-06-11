output "controller_ip" {
  value = google_compute_address.controller_ip.address
}

output "worker_ips" {
  value = google_compute_address.worker_ips[*].address
}

output "jumpbox_ip" {
  value = google_compute_instance.jumpbox.network_interface[0].access_config[0].nat_ip
}


