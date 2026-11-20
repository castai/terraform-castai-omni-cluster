locals {
  network = coalesce(var.network, one(google_compute_network.edge[*].self_link))
}

resource "google_compute_network" "edge" {
  count = var.network == null ? 1 : 0

  name                    = "${var.name}-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "edge" {
  name          = "${var.name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = local.network
}

resource "google_compute_firewall" "edge_ssh" {
  name    = "${var.name}-ssh"
  network = local.network

  # Lock this down to your own address for anything longer lived than a demo.
  source_ranges = var.ssh_source_ranges

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["omni-edge"]
}

resource "google_compute_instance" "edge" {
  for_each = { for edge in var.edges : edge.name => edge }

  name         = each.key
  zone         = coalesce(each.value.zone, "${var.region}-a")
  machine_type = coalesce(each.value.machine_type, var.default_machine_type)

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = var.boot_disk_size
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.edge.id
    # The join command dials the cluster's control plane over this address;
    # everything else rides the encrypted omninet overlay.
    access_config {}
  }

  tags = ["omni-edge"]

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  # The kubelet and the agent need the extra sysctls; the join command
  # applies most of this, a warm-up apt update keeps the first join fast.
  metadata_startup_script = <<-EOT
    #!/bin/sh
    set -e
    apt-get update || true
  EOT
}
