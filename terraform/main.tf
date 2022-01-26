terraform {
  required_version = ">= 0.14"
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

variable "cluster_name" {}
variable "server_image_name" {}
variable "client_image_name" {}
variable "server_flavor_name" {}
variable "client_flavor_name" {}
variable "key_pair" {}
variable "network_name" {}
variable "rdma_network_name" {}
variable "mgs_volume_id" {}
variable "mdt_volume_id" {}
variable "ost_volume_id" {}

variable "clients" {
    default = ["admin-client", "ganesha-server"]
}

data "openstack_images_image_v2" "server_image" {
    name = var.server_image_name
}

data "openstack_networking_network_v2" "rdma_net" {
  name = var.rdma_network_name
}

resource "openstack_networking_port_v2" "rdma" {
  
  for_each = toset(concat(["lustre-server"], var.clients))

  name = "${var.cluster_name}-${each.key}-rdma"
  network_id = data.openstack_networking_network_v2.rdma_net.id
  admin_state_up = "true"

  binding {
    vnic_type = "direct"
  }

}

resource "openstack_compute_instance_v2" "server" {

    name = "${var.cluster_name}-lustre-server"
    image_name = var.server_image_name
    flavor_name = var.server_flavor_name
    key_pair = var.key_pair
    config_drive = true
    security_groups = ["default"]

    network {
        name = var.network_name
        access_network = true
    }

    // network {
    //   port = openstack_networking_port_v2.rdma["lustre-server"].id
    // }

}

resource "openstack_compute_instance_v2" "clients" {
  
  for_each = toset(var.clients)
  name = "${var.cluster_name}-${each.key}"
  image_name = var.client_image_name
  flavor_name = var.client_flavor_name
  key_pair = var.key_pair
  config_drive = true
  security_groups = ["default"]

  network {
    name = var.network_name
    access_network = true
  }

  network {
    port = openstack_networking_port_v2.rdma[each.key].id
  }
}

resource "local_file" "hosts" {
  content = templatefile("${path.module}/inventory.tpl",
    {
      "cluster_name" : var.cluster_name
      "server" : openstack_compute_instance_v2.server,
      "clients" : openstack_compute_instance_v2.clients,
    },
  )
  filename = "${path.module}/../inventory/hosts"
}