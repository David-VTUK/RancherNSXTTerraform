provider "rancher2" {
  api_url    = "https://rancher.virtualthoughts.co.uk"
  access_key = var.rancher2_access_key
  secret_key = var.rancher2_secret_key
  insecure = "true"
}

# Create a new rancher2 Cloud Credential
resource "rancher2_cloud_credential" "vsphere-terraform" {
  name = "vsphere-terraform"
  description = "Terraform Credentials"
  vsphere_credential_config {
    username = "Terraform@vsphere.local"
    password = "Terraform123!"
    vcenter = "svr-vcs-01.virtualthoughts.co.uk"
  }
}


resource "rancher2_node_template" "vSphere-NSXT-Template" {
  name = "vSphere-NSXT-Template"
  description = "Created by Terraform"
  cloud_credential_id = rancher2_cloud_credential.vsphere-terraform.id
   vsphere_config {
   cfgparam = ["disk.enableUUID=TRUE"]
   clone_from = var.template_name
   cpu_count = var.template_num_cpu
   creation_type = "template"
   disk_size = var.template_disk_size
   memory_size = var.node_mem_size
   datastore = var.node_datastore
   datacenter = var.node_datacenter
   pool = var.node_resourcepool
   network = [nsxt_logical_switch.k8s-mgmt.display_name ,nsxt_logical_switch.k8s-overlay.display_name]
   }
  depends_on = [
    nsxt_logical_switch.k8s-overlay,
    nsxt_logical_switch.k8s-mgmt
  ]

  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# Create a new rancher2 Node Pool
resource "rancher2_node_pool" "nodepool" {
  cluster_id =  rancher2_cluster.vsphere-test-nsxt.id
  name = "all-in-one"
  hostname_prefix =  "vsphere-nsxt-cluster-"
  node_template_id = rancher2_node_template.vSphere-NSXT-Template.id
  quantity = 1
  control_plane = true
  etcd = true
  worker = true

    provisioner "local-exec" {
    command = "sleep 60"
  }
}

# Create a new rancher2 RKE Cluster
resource "rancher2_cluster" "vsphere-test-nsxt" {
  name = "vsphere-test-nsxt"
  description = "Terraform created vSphere Cluster"
  rke_config {
  kubernetes_version = "v1.16.6-rancher1-2"
   network {
      plugin = "none"
   }
   services {
     kubelet {
       extra_binds = [
         "/var/cache/:/var/cache/",
        "/sbin/apparmor_parser:/sbin/apparmor_parser",
       ]
     }
     kube_api {
       extra_args = {
         "allow-privileged" = true
       } 
     }
   }
    addons = template_file.policy.rendered
      }
}