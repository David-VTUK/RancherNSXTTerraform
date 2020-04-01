resource "template_file" "policy" {
  template = file("${path.module}/ncp.tpl")
  vars = {
      nsx_api_user = var.nsxt_username
      nsx_api_password = var.nsxt_password
      container_ip_blocks = var.nsx_container_ipblocks
      top_tier_router = var.nsxt_logical_tier0_router
      edge_cluster = data.nsxt_edge_cluster.edgecluster.id
      cluster = var.clustername
      apiserver_host_ip = var.k8s_api_lb_ip
      apiserver_host_port = "6443"
      ovs_uplink_port = var.ovs_uplink_port
      nsx_api_managers = var.nsxt_host
      external_ip_pools_lb = var.external_ip_pools_lb
      overlay_tz = data.nsxt_transport_zone.overlay_transport_zone.id
      top_firewall_section_marker = ""
      bottom_firewall_section_marker = ""
      ncp_image_location = var.ncp_image_location
    }
}

resource "local_file" "foo" {
    content     = template_file.policy.rendered
    filename = "${path.module}/output.yaml"
}
