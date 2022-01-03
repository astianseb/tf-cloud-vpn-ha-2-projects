resource "google_compute_instance" "vpc_demo_instance1" {
  name         = "vpc-demo-instance1"
  machine_type = "e2-medium"
  zone         = local.region-a-zone-a
  project      = google_project.project["project_a"].project_id

  tags = ["notag"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_demo.name
    subnetwork = google_compute_subnetwork.vpc_demo_subnet1.self_link
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

  metadata = {
    enable-oslogin = true
  }
}


resource "google_compute_instance" "on_prem_instance1" {
  name         = "on-prem-instance1"
  machine_type = "e2-medium"
  zone         = local.region-a-zone-a
  project      = google_project.project["project_b"].project_id

  tags = ["notag"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network    = google_compute_network.on_prem.name
    subnetwork = google_compute_subnetwork.on_prem_subnet1.self_link
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

  metadata = {
    enable-oslogin = true
  }
}