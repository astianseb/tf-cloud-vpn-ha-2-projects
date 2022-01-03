################ VPC in the cloud (project_a) ##################
resource "google_compute_network" "vpc_demo" {
  name                    = "vpc-demo"
  auto_create_subnetworks = false
  mtu                     = 1460
  project                 = google_project.project["project_a"].project_id
}

resource "google_compute_subnetwork" "vpc_demo_subnet1" {
  name          = "vpc-demo-subnet1"
  region        = var.region_a
  project       = google_project.project["project_a"].project_id
  ip_cidr_range = "10.1.1.0/24"
  network       = google_compute_network.vpc_demo.id
}

resource "google_compute_subnetwork" "vpc_demo_subnet2" {
  name    = "vpc-demo-subnet2"
  region  = var.region_b
  project = google_project.project["project_a"].project_id
  ip_cidr_range = "10.1.2.0/24"
  network = google_compute_network.vpc_demo.id
}

resource "google_compute_firewall" "vpc_demo_allow_internal" {
  name      = "vpc-demo-allow-internal"
  project   = google_project.project["project_a"].project_id
  network   = google_compute_network.vpc_demo.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [google_compute_subnetwork.vpc_demo_subnet1.ip_cidr_range,
  google_compute_subnetwork.vpc_demo_subnet2.ip_cidr_range]
}

resource "google_compute_firewall" "vpc_demo_allow_ssh_icmp" {
  name      = "vpc-demo-allow-ssh-icmp"
  project   = google_project.project["project_a"].project_id
  network   = google_compute_network.vpc_demo.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}


resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  region  = var.region_a
  project = google_project.project["project_a"].project_id
  network = google_compute_network.vpc_demo.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "my-router-nat"
  region                             = var.region_a
  project                            = google_project.project["project_a"].project_id
  router                             = google_compute_router.nat_router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}



################# VPC on-prem (project_b) #####################

resource "google_compute_network" "on_prem" {
  name                    = "on-prem"
  auto_create_subnetworks = false
  mtu                     = 1460
  project                 = google_project.project["project_b"].project_id
}

resource "google_compute_subnetwork" "on_prem_subnet1" {
  name          = "on-prem-subnet1"
  region        = var.region_a
  project       = google_project.project["project_b"].project_id
  ip_cidr_range = "192.168.1.0/24"
  network       = google_compute_network.on_prem.id
}

resource "google_compute_firewall" "on_prem_allow_internal" {
  name      = "on-prem-allow-internal"
  project   = google_project.project["project_b"].project_id
  network   = google_compute_network.on_prem.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [google_compute_subnetwork.on_prem_subnet1.ip_cidr_range]
}

resource "google_compute_firewall" "on_prem_allow_ssh_icmp" {
  name      = "on-prem-allow-ssh-icmp"
  project   = google_project.project["project_b"].project_id
  network   = google_compute_network.on_prem.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}