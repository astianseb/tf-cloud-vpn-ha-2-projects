variable "vpn"  {
    default = {
        ip_ranges = {
            tunnel_1 = "169.254.0.0/30"
            tunnel_2 = "169.254.0.4/30"
        }
        secret = "kluczyk."
        project_a = {
            vpn_region = "europe-central2"
            router_asn = "65001"
        }
        project_b = {
            vpn_region = "europe-central2"
            router_asn = "65002"
            ip_range = "169.254.0.4/30"
        }
    }
}

# separate local variable for GW due to race condition/ambiguity with terraform graph. Therefore
# GW needs to be created separately (ugly hack though)
locals {
    gateway = {
        project_a = {
           vpn_region       = var.vpn.project_a.vpn_region
           vpn_gateway_name = "vpn-gw-${var.projects.project_a.vpc_name}"
        }
        project_b = {
           vpn_region       = var.vpn.project_b.vpn_region
           vpn_gateway_name = "vpn-gw-${var.projects.project_b.vpc_name}"
        }
    }
}



locals  {
    vpn = {
       project_a = {
           vpn_region      = var.vpn.project_a.vpn_region
           vpn_network_id  = google_compute_network.network["project_a"].id
           vpn_gateway_name = "vpn-gw-${var.projects.project_a.vpc_name}"
           vpn_router_name = "rtr-vpn-${var.projects.project_a.vpc_name}"
           vpn_router_asn  = var.vpn.project_a.router_asn
           vpn_project_id  = google_project.project["project_a"].project_id
           tunnels = [
               {
                   peer_gcp_gateway_id   = google_compute_ha_vpn_gateway.vpn_gw["project_b"].id
                   peer_gcp_gateway_name = google_compute_ha_vpn_gateway.vpn_gw["project_b"].name
                   secret                = var.vpn.secret
                   interface =  {
                          ip_range = "${cidrhost(var.vpn.ip_ranges.tunnel_1, 1)}/30"
                          bgp_peer = "${cidrhost(var.vpn.ip_ranges.tunnel_1, 2)}"
                          peer_asn = var.vpn.project_b.router_asn
                      }
               },
               {
                   peer_gcp_gateway_id   = google_compute_ha_vpn_gateway.vpn_gw["project_b"].id
                   peer_gcp_gateway_name = google_compute_ha_vpn_gateway.vpn_gw["project_b"].name
                   secret                = var.vpn.secret
                   interface = {
                          ip_range = "${cidrhost(var.vpn.ip_ranges.tunnel_2, 1)}/30"
                          bgp_peer = "${cidrhost(var.vpn.ip_ranges.tunnel_2, 2)}"
                          peer_asn = var.vpn.project_b.router_asn
                        }
               }
           ]
        }
        project_b = {
            vpn_region       = var.vpn.project_a.vpn_region
            vpn_network_id   = google_compute_network.network["project_b"].id
            vpn_gateway_name = "vpn-gw-${var.projects.project_b.vpc_name}"
            vpn_router_name  = "rtr-vpn-${var.projects.project_b.vpc_name}"
            vpn_router_asn   = var.vpn.project_b.router_asn
            vpn_project_id   = google_project.project["project_b"].project_id
            tunnels = [
               {
                   peer_gcp_gateway_id   = google_compute_ha_vpn_gateway.vpn_gw["project_a"].id
                   peer_gcp_gateway_name = google_compute_ha_vpn_gateway.vpn_gw["project_a"].name
                   secret                = var.vpn.secret
                   interface =  {
                          ip_range = "${cidrhost(var.vpn.ip_ranges.tunnel_1, 2)}/30"
                          bgp_peer = "${cidrhost(var.vpn.ip_ranges.tunnel_1, 1)}"
                          peer_asn = var.vpn.project_a.router_asn
                      }
               },
                {
                   peer_gcp_gateway_id   = google_compute_ha_vpn_gateway.vpn_gw["project_a"].id
                   peer_gcp_gateway_name = google_compute_ha_vpn_gateway.vpn_gw["project_a"].name
                   secret                = var.vpn.secret
                   interface =  {
                          ip_range = "${cidrhost(var.vpn.ip_ranges.tunnel_2, 2)}/30"
                          bgp_peer = "${cidrhost(var.vpn.ip_ranges.tunnel_2, 1)}"
                          peer_asn = var.vpn.project_a.router_asn
                        }
               }

                  ]
               
        }
    } 
}



resource "google_compute_ha_vpn_gateway" "vpn_gw" {
    for_each = local.gateway

    name    = each.value.vpn_gateway_name
    region  = each.value.vpn_region
    project = google_project.project["${each.key}"].project_id
    network = google_compute_network.network["${each.key}"].id
}


resource "google_compute_router" "vpn_router" {
    for_each = local.vpn

    name    = each.value.vpn_router_name
    region  = each.value.vpn_region
    project = google_project.project["${each.key}"].project_id
    network = google_compute_network.network["${each.key}"].id
    bgp {
      asn = each.value.vpn_router_asn
     }
    }

locals {
    tunnels = flatten([ for project,parameter in local.vpn :
                             [ for k,v in parameter.tunnels :
                                 { name                  = "${project}",
                                   region                = parameter.vpn_region,
                                   project               = google_project.project["${project}"].project_id,
                                   vpn_gateway           = google_compute_ha_vpn_gateway.vpn_gw["${project}"].id,
                                   peer_gcp_gateway      = v.peer_gcp_gateway_id,
                                   peer_gcp_gateway_name = v.peer_gcp_gateway_name,
                                   shared_secret         = v.secret,
                                   router                = google_compute_router.vpn_router["${project}"].id
                                   index                 = k
                                   }]])

}


resource "google_compute_vpn_tunnel" "tunnel" {
    for_each = { for k,v in local.tunnels : "${v.name}_${v.index}" => v }

    name                  = "tunnel-${each.value.index}-to-${each.value.peer_gcp_gateway_name}"
    region                = each.value.region
    project               = each.value.project
    vpn_gateway           = each.value.vpn_gateway
    peer_gcp_gateway      = each.value.peer_gcp_gateway
    shared_secret         = each.value.shared_secret
    router                = each.value.router
    vpn_gateway_interface = each.value.index
}


locals {
    interfaces = flatten([ for project, project_vars in local.vpn : 
                    [ for tunnel_index, tunnel_vars in project_vars.tunnels :
                            {   name       = "${project_vars.vpn_router_name}-interface${tunnel_index}"
                                project    = google_project.project["${project}"].project_id
                                router     = google_compute_router.vpn_router["${project}"].name
                                region     = project_vars.vpn_region
                                ip_range   = tunnel_vars.interface.ip_range
                                vpn_tunnel = google_compute_vpn_tunnel.tunnel["${project}_${tunnel_index}"].name
                                index      = tunnel_index
                            }]])
}




resource "google_compute_router_interface" "interface" {
    for_each = { for k,v in local.interfaces : "${v.name}_${v.index}" => v }

    name       = each.value.name
    router     = each.value.router
    region     = each.value.region
    project    = each.value.project
    ip_range   = each.value.ip_range
    vpn_tunnel = each.value.vpn_tunnel
}


locals {
    peers = flatten([ for project, project_vars in local.vpn : 
                    [ for tunnel_index, tunnel_vars in project_vars.tunnels : 
                        {  name            = "${project_vars.vpn_router_name}-peer${tunnel_index}"
                           project         = google_project.project["${project}"].project_id
                           router          = google_compute_router.vpn_router["${project}"].name
                           region          = project_vars.vpn_region
                           peer_ip_address = tunnel_vars.interface.bgp_peer
                           peer_asn        = tunnel_vars.interface.peer_asn
                           index           = tunnel_index

                        }]])
}


resource "google_compute_router_peer" "peer" {
    for_each = { for k,v in local.peers : "${v.name}_${v.index}" => v }

    name = each.value.name
    router = each.value.router
    region = each.value.region
    project = each.value.project
    peer_ip_address = each.value.peer_ip_address
    peer_asn = each.value.peer_asn
    advertised_route_priority = "100"
    interface = google_compute_router_interface.interface["${each.value.router}-interface${each.value.index}_${each.value.index}"].name

}

