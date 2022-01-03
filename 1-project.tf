variable "projects" {
  type = map(any)
  default = {
    project_a = {
      name = "prj-a"
    }
    project_b = {
      name = "prj-b"
    }
  }

}


resource "random_id" "id" {
  for_each = var.projects

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
  for_each = var.projects

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