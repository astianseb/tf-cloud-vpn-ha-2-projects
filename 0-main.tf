variable "region_a" {}
variable "region_b" {}


variable "project_name_a" {}

variable "project_name_b" {}


variable "billing_account" {}

locals {
  region-a-zone-a = "${var.region_a}-a"
  region-a-zone-b = "${var.region_a}-b"
}

provider "google" {
}
