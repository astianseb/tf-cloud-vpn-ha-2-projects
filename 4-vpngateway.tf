resource "google_compute_ha_vpn_gateway" "ha_gw_vpc_demo" {
  name    = "ha-gw-vpc-demo"
  region  = var.region_a
  project = google_project.project["project_a"].project_id
  network = google_compute_network.vpc_demo.id
}

resource "google_compute_ha_vpn_gateway" "ha_gw_on_prem" {
  name    = "ha-gw-on-prem"
  region  = var.region_a
  project = google_project.project["project_b"].project_id
  network = google_compute_network.on_prem.id
}

resource "google_compute_router" "rtr_vpn_vpc_demo" {
  name    = "rtr-vpn-vpc-demo"
  region  = var.region_a
  project = google_project.project["project_a"].project_id
  network = google_compute_network.vpc_demo.name
  bgp {
    asn = 65001
  }
}

resource "google_compute_router" "rtr_vpn_on_prem" {
  name    = "rtr-vpn-on-prem"
  region  = var.region_a
  project = google_project.project["project_b"].project_id
  network = google_compute_network.on_prem.name
  bgp {
    asn = 65002
  }
}

resource "google_compute_vpn_tunnel" "tunnel1_to_onprem" {
  name                  = "tunnel1-to-onprem"
  region                = var.region_a
  project               = google_project.project["project_a"].project_id
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gw_vpc_demo.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_gw_on_prem.id
  shared_secret         = "secret."
  router                = google_compute_router.rtr_vpn_vpc_demo.id
  vpn_gateway_interface = 0
}

resource "google_compute_vpn_tunnel" "tunnel2_to_onprem" {
  name                  = "tunnel2-to-onprem"
  region                = var.region_a
  project               = google_project.project["project_a"].project_id
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gw_vpc_demo.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_gw_on_prem.id
  shared_secret         = "secret."
  router                = google_compute_router.rtr_vpn_vpc_demo.id
  vpn_gateway_interface = 1
}

resource "google_compute_vpn_tunnel" "tunnel1_to_vpc_demo" {
  name                  = "tunnel1-to-vpc-demo"
  region                = var.region_a
  project               = google_project.project["project_b"].project_id
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gw_on_prem.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_gw_vpc_demo.id
  shared_secret         = "secret."
  router                = google_compute_router.rtr_vpn_on_prem.id
  vpn_gateway_interface = 0
}

resource "google_compute_vpn_tunnel" "tunnel2_to_vpc_demo" {
  name                  = "tunnel2-to-vpc-demo"
  region                = var.region_a
  project               = google_project.project["project_b"].project_id
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gw_on_prem.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_gw_vpc_demo.id
  shared_secret         = "secret."
  router                = google_compute_router.rtr_vpn_on_prem.id
  vpn_gateway_interface = 1
}

resource "google_compute_router_interface" "rtr_vpn_vpc_demo_interface1" {
  name       = "rtr-vpn-vpc-demo-interface1"
  router     = google_compute_router.rtr_vpn_vpc_demo.name
  region     = var.region_a
  project    = google_project.project["project_a"].project_id
  ip_range   = "169.254.0.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel1_to_onprem.name
}



resource "google_compute_router_peer" "rtr_vpn_vpc_demo_peer1" {
  name                      = "rtr-vpn-vpc-demo-peer1"
  router                    = google_compute_router.rtr_vpn_vpc_demo.name
  region                    = var.region_a
  project                   = google_project.project["project_a"].project_id
  peer_ip_address           = "169.254.0.2"
  peer_asn                  = 65002
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.rtr_vpn_vpc_demo_interface1.name
}

resource "google_compute_router_interface" "rtr_vpn_vpc_demo_interface2" {
  name       = "rtr-vpn-vpc-demo-interface2"
  router     = google_compute_router.rtr_vpn_vpc_demo.name
  region     = var.region_a
  project    = google_project.project["project_a"].project_id
  ip_range   = "169.254.1.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel2_to_onprem.name
}

resource "google_compute_router_peer" "rtr_vpn_vpc_demo_peer2" {
  name                      = "rtr-vpn-vpc-demo-peer2"
  router                    = google_compute_router.rtr_vpn_vpc_demo.name
  region                    = var.region_a
  project                   = google_project.project["project_a"].project_id
  peer_ip_address           = "169.254.1.2"
  peer_asn                  = 65002
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.rtr_vpn_vpc_demo_interface2.name
}

resource "google_compute_router_interface" "rtr_vpn_on_prem_interface1" {
  name       = "rtr-vpn-on-prem-interface1"
  router     = google_compute_router.rtr_vpn_on_prem.name
  region     = var.region_a
  project    = google_project.project["project_b"].project_id
  ip_range   = "169.254.0.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel1_to_vpc_demo.name
}

resource "google_compute_router_peer" "rtr_vpn_on_prem_peer1" {
  name                      = "rtr-vpn-on-prem-peer1"
  router                    = google_compute_router.rtr_vpn_on_prem.name
  region                    = var.region_a
  project                   = google_project.project["project_b"].project_id
  peer_ip_address           = "169.254.0.1"
  peer_asn                  = 65001
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.rtr_vpn_on_prem_interface1.name
}

resource "google_compute_router_interface" "rtr_vpn_on_prem_interface2" {
  name       = "rtr-vpn-on-prem-interface2"
  router     = google_compute_router.rtr_vpn_on_prem.name
  region     = var.region_a
  project    = google_project.project["project_b"].project_id
  ip_range   = "169.254.1.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel2_to_vpc_demo.name
}

resource "google_compute_router_peer" "rtr_vpn_on_prem_peer2" {
  name                      = "rtr-vpn-on-prem-peer2"
  router                    = google_compute_router.rtr_vpn_on_prem.name
  region                    = var.region_a
  project                   = google_project.project["project_b"].project_id
  peer_ip_address           = "169.254.1.1"
  peer_asn                  = 65001
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.rtr_vpn_on_prem_interface2.name
}