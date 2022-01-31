terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

variable "name" {}
variable "image_name" {}
variable "flavor_name" {}
variable "key_pair" {}
variable "network_name" {}
variable "rdma_network_name" {}
variable "security_groups" {
  default = ["default"]
}

data "openstack_networking_network_v2" "rdma_net" {
  name = var.rdma_network_name
}

resource "openstack_networking_port_v2" "rdma" {
  
  name = "${var.name}-rdma"
  network_id = data.openstack_networking_network_v2.rdma_net.id
  admin_state_up = "true"

  binding {
    vnic_type = "direct"
  }

}

resource "openstack_compute_instance_v2" "host" {

    name = var.name
    image_name = var.image_name
    flavor_name = var.flavor_name
    key_pair = var.key_pair
    config_drive = true
    security_groups = var.security_groups

    network {
        name = var.network_name
        access_network = true
    }

    network {
      port = openstack_networking_port_v2.rdma.id
    }

}
