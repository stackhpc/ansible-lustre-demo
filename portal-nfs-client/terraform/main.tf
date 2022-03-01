# Models / allows for testing a Portal-created NON-RDMA-capable VM without using the portal
terraform {
  required_version = ">= 0.14"
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

variable "image_name" {
  default = "RockyLinux-8.5-20211114.2"
}
variable "flavor_name" {
  default = "vm.iris.cpu.dac.quarter"
}
variable "exporter_network_name" {
  default = "portal-internal"
}
variable "key_pair" {
  default = "steveb-rcp-cloud-portal-demo-deploy-v1"
}

variable "security_groups" {
  default = ["default"]
}

data "openstack_networking_network_v2" "exporter_net" {
  name = var.exporter_network_name
}

resource "openstack_networking_port_v2" "client" {
  
  name = "demo-client"
  network_id = data.openstack_networking_network_v2.exporter_net.id
  admin_state_up = "true"

}

resource "openstack_compute_instance_v2" "client" {

    name = "demo-client"
    image_name = var.image_name
    flavor_name = var.flavor_name
    key_pair = var.key_pair
    config_drive = true
    security_groups = var.security_groups

    network {
      port = openstack_networking_port_v2.client.id
      access_network = true
    }

}


resource "local_file" "hosts" {
  content = templatefile("${path.module}/inventory.tpl",
    {
      "client" : openstack_compute_instance_v2.client,
    },
  )
  filename = "${path.module}/../inventory/hosts"
}
