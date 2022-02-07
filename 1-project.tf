variable "projects" {
  type = map(any)
  default = {
    project_a = {
      name     = "prj-cloud"
      vpc_name = "vpc-cloud"
    }
    project_b = {
      name     = "prj-onprem"
      vpc_name = "vpc-onprem"
    }
  }

}

locals {
  projects = {
    project_a = {
      name     = "${var.projects.project_a.name}"
      vpc_name = "${var.projects.project_a.vpc_name}"
      subnets = [
        { subnet_name   = "${var.projects.project_a.vpc_name}-subnet1"
          subnet_cidr   = "10.1.1.0/24"
          subnet_region = "europe-central2"
        },
        {
          subnet_name   = "${var.projects.project_a.vpc_name}-subnet2"
          subnet_cidr   = "10.1.2.0/24"
          subnet_region = "europe-central2"
        }
      ]
      nat_router_name   = "${var.projects.project_a.vpc_name}-rtr"
      nat_router_region = "europe-central2"
      nat_router_asn    = "64514"
    }
    project_b = {
      name     = "${var.projects.project_b.name}"
      vpc_name = "${var.projects.project_b.vpc_name}"
      subnets = [
        { subnet_name   = "${var.projects.project_b.vpc_name}-subnet1"
          subnet_cidr   = "10.2.1.0/24"
          subnet_region = "europe-central2"

        },
        {
          subnet_name   = "${var.projects.project_b.vpc_name}-subnet2"
          subnet_cidr   = "10.2.2.0/24"
          subnet_region = "europe-central2"
        }
      ]
      nat_router_name   = "${var.projects.project_a.vpc_name}-rtr"
      nat_router_region = "europe-central2"
      nat_router_asn    = "64515"
    }
  }
}



resource "random_id" "id" {
  for_each = local.projects

  byte_length = 4
  prefix      = "${each.value.name}-"
}


resource "google_project" "project" {
  for_each = var.projects

  name                = each.value.name
  project_id          = random_id.id[each.key].hex
  billing_account     = var.billing_account
  auto_create_network = false
}

resource "google_project_service" "service" {
  for_each = local.projects

  service            = "compute.googleapis.com"
  project            = google_project.project[each.key].project_id
  disable_on_destroy = false
}



output "project_a_id" {
  value = google_project.project["project_a"].project_id
}

output "project_b_id" {
  value = google_project.project["project_b"].project_id
}