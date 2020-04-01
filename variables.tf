variable "nsxt_edgecluster" {}
variable "nsxt_host" {}
variable "nsxt_username" {}
variable "nsxt_password" {}
variable "nsxt_logical_tier0_router" {}
variable "nsxt_overlay_tz" {}



# K8s-specific

variable "k8s_api_lb_ip" {}
variable "vsphere_user" {}
variable "vsphere_password" {}
variable "vsphere_server" {}
variable "nsx_container_ipblocks" {}
variable "external_ip_pools_lb" {}
variable "clustername" {}
variable "ovs_uplink_port" {}
variable "apiserver_host_port" {}
variable "ncp_image_location" {}

# Node-specific

variable template_name {}
variable template_num_cpu {}
variable template_disk_size {}
variable node_datastore {}
variable node_datacenter {}
variable node_resourcepool {}
variable node_mem_size {}

# Rancher-specific

variable "rancher2_access_key" {}
variable "rancher2_secret_key" {}
variable "rancher2_baseurl" {}
variable "rancher2_clusterid" {}



