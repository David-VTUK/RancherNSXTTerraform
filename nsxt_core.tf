

## Extrapolate required components, such as T0 router, Edge Cluster, etc

data "nsxt_logical_tier0_router" "tier0_router" {
  display_name = var.nsxt_logical_tier0_router
}

data "nsxt_transport_zone" "overlay_transport_zone" {
  display_name = var.nsxt_overlay_tz
}

data "nsxt_edge_cluster" "edgecluster" {
  display_name = var.nsxt_edgecluster
}

output "T0-ID" {
    value = "${data.nsxt_logical_tier0_router.tier0_router.id}" 
}

output "Edgecluster-ID" {
    value = "${data.nsxt_edge_cluster.edgecluster.id}"
}

output "Transportzone-ID" {
    value = "${data.nsxt_transport_zone.overlay_transport_zone.id}"
}

## Create k8s_mgmt T1 router

resource "nsxt_logical_tier1_router" "k8s_mgmt" {
  description                 = "RTR1 provisioned by Terraform"
  display_name                = "k8s_mgmt"
  failover_mode               = "PREEMPTIVE"
  edge_cluster_id             = data.nsxt_edge_cluster.edgecluster.id
  enable_router_advertisement = true
  advertise_connected_routes  = true
  advertise_static_routes     = false
  advertise_nat_routes        = true
  advertise_lb_vip_routes     = true
  advertise_lb_snat_ip_routes = true
  
}

resource "nsxt_logical_port" "k8s-mgmt" {
  admin_state       = "UP"
  description       = "LP1 provisioned by Terraform"
  display_name      = "LP1"
  logical_switch_id = nsxt_logical_switch.k8s-mgmt.id
}

resource "nsxt_logical_router_downlink_port" "k8s_mgmt_downlink_port" {
  description                   = "DP1 provisioned by Terraform"
  display_name                  = "DP1"
  logical_router_id             = nsxt_logical_tier1_router.k8s_mgmt.id
  linked_logical_switch_port_id = nsxt_logical_port.k8s-mgmt.id
  ip_address = "10.80.80.1/24"
}

## Connect routers together

resource "nsxt_logical_router_link_port_on_tier0" "link_port_tier0_k8s_mgmt" {
  description       = "TIER0_PORT1 provisioned by Terraform"
  display_name      = "TIER0_PORT1"
  logical_router_id = data.nsxt_logical_tier0_router.tier0_router.id
}

resource "nsxt_logical_router_link_port_on_tier1" "link_port_tier1_k8s_mgmt" {
  description                   = "TIER1_PORT1 provisioned by Terraform"
  display_name                  = "TIER1_PORT1"
  logical_router_id             = nsxt_logical_tier1_router.k8s_mgmt.id
  linked_logical_router_port_id = nsxt_logical_router_link_port_on_tier0.link_port_tier0_k8s_mgmt.id
}

## Create Segments

resource "nsxt_logical_switch" "k8s-overlay" {
  admin_state       = "UP"
  description       = "LS1 provisioned by Terraform"
  display_name      = "k8s-overlay"
  transport_zone_id = data.nsxt_transport_zone.overlay_transport_zone.id
  replication_mode  = "MTEP"
   tag {
    scope       = "k8soverlay"
    tag         = "role"
  }
}

resource "nsxt_logical_switch" "k8s-mgmt" {
  admin_state       = "UP"
  description       = "LS1 provisioned by Terraform"
  display_name      = "k8s-mgmt"
  transport_zone_id = data.nsxt_transport_zone.overlay_transport_zone.id
  replication_mode  = "MTEP"
  }


## Create DHCP profile

resource "nsxt_dhcp_server_profile" "serverprofile" {
  edge_cluster_id = data.nsxt_edge_cluster.edgecluster.id
}


## DHCP Server profile to be used by both DHCP servers

resource "nsxt_dhcp_server_profile" "dhcp_profile-k8s" {
  description                 = "dhcp_profile provisioned by Terraform"
  display_name                = "dhcp_profile-k8s"
  edge_cluster_id             = data.nsxt_edge_cluster.edgecluster.id
}


## DHCP Server configuration for management

resource "nsxt_logical_dhcp_server" "logical_dhcp_server_k8s_mgmt" {
  display_name     = "logical_dhcp_server_k8s_mgmt"
  description      = "logical_dhcp_server provisioned by Terraform"
  dhcp_profile_id  = nsxt_dhcp_server_profile.dhcp_profile-k8s.id
  dhcp_server_ip   = "10.80.80.2/24"
  gateway_ip       = "10.80.80.1"
  dns_name_servers = ["172.16.10.30"]
}

resource "nsxt_dhcp_server_ip_pool" "dhcp_ip_pool_k8s_mgmt" {
  display_name           = "dhcp_ip_pool-k8s"
  description            = "dhcp_ip_pool-k8s"
  logical_dhcp_server_id = nsxt_logical_dhcp_server.logical_dhcp_server_k8s_mgmt.id
  gateway_ip             = "10.80.80.1"
  lease_time             = 1296000
  error_threshold        = 98
  warning_threshold      = 70

  ip_range {
    start = "10.80.80.10"
    end   = "10.80.80.200"
  }
}

resource "nsxt_logical_dhcp_port" "dhcp_port_k8s_mgmt" {
  admin_state       = "UP"
  description       = "LP1 provisioned by Terraform"
  display_name      = "LP1"
  logical_switch_id = nsxt_logical_switch.k8s-mgmt.id
  dhcp_server_id    = nsxt_logical_dhcp_server.logical_dhcp_server_k8s_mgmt.id
}

## DHCP Server configuration for Overlay

resource "nsxt_logical_dhcp_server" "logical_dhcp_server_k8s_overlay" {
  display_name     = "logical_dhcp_server"
  description      = "logical_dhcp_server provisioned by Terraform"
  dhcp_profile_id  = nsxt_dhcp_server_profile.dhcp_profile-k8s.id
  dhcp_server_ip   = "10.80.90.2/24"
  gateway_ip       = "10.80.90.1"
  dns_name_servers = ["172.16.10.30"]
}

resource "nsxt_dhcp_server_ip_pool" "dhcp_ip_pool_k8s_overlay" {
  display_name           = "dhcp_ip_pool-overlay"
  description            = "dhcp_ip_pool-overlay"
  logical_dhcp_server_id = nsxt_logical_dhcp_server.logical_dhcp_server_k8s_overlay.id
  gateway_ip             = "10.80.90.1"
  lease_time             = 1296000
  error_threshold        = 98
  warning_threshold      = 70

  ip_range {
    start = "10.80.90.10"
    end   = "10.80.90.254"
  }
  
}

resource "nsxt_logical_dhcp_port" "dhcp_port_k8s_overlay" {
  admin_state       = "UP"
  description       = "LP1 provisioned by Terraform"
  display_name      = "LP1"
  logical_switch_id = nsxt_logical_switch.k8s-overlay.id
  dhcp_server_id    = nsxt_logical_dhcp_server.logical_dhcp_server_k8s_overlay.id
}
  