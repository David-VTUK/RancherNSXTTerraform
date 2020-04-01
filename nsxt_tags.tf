
data "vsphere_virtual_machine" "vm1" {
  name = join("",[rancher2_node_pool.nodepool.hostname_prefix,"1"])
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "nsxt_vm_tags" "vm1_tags" {
  instance_id = data.vsphere_virtual_machine.vm1.id

  tag {
    scope = "ncp/cluster_name"
    tag   = "terraform"
  }

  logical_port_tag {
    scope = "ncp/cluster_name"
    tag   = var.clustername
    
  }

  logical_port_tag {
    scope = "ncp/node_name"
    tag   = data.vsphere_virtual_machine.vm1.name
}

}
