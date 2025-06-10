variable "project_id" {
  default = "creature-vision"
}
variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-a"
}

variable "controller_count" {
  default = 1
}

variable "worker_count" {
  default = 2
}

variable "controller_machine_type" {
  default = "e2-medium"
}

variable "worker_machine_type" {
  default = "e2-micro"
}

variable "disk_size_gb" {
  default = 20
}

variable "ssh_user" {
  default = "trey"
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "subnetwork" {
  default = "kubernetes"
}


variable "image" {
  default = "debian-12-bookworm-v20250513"
}

