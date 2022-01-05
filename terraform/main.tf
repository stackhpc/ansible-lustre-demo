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
variable "flavor_name" {}
variable "key_pair" {}
variable "network_name" {}
variable "mgs_volume_id" {}
variable "mdt_volume_id" {}
variable "ost_volume_id" {}

variable "clients" {
    default = ["client-1", "client-2"]
}

data "openstack_images_image_v2" "server_image" {
    name = var.server_image_name
}

resource "openstack_compute_instance_v2" "server" {

    name = "${var.cluster_name}-server"
    image_name = var.server_image_name
    flavor_name = var.flavor_name
    key_pair = var.key_pair
    config_drive = true
    security_groups = ["default"]

    network {
        name = var.network_name
        access_network = true
    }

    # have to specify ephemeral disk if specifying volumes here too:
    block_device {
        uuid = data.openstack_images_image_v2.server_image.id
        source_type  = "image"
        destination_type = "local"
        boot_index = 0
        delete_on_termination = true
    }
    
    # MGS:
    block_device {
        destination_type = "volume"
        source_type  = "volume"
        boot_index = -1
        uuid = var.mgs_volume_id
    }

    # MDT:
    block_device {
        destination_type = "volume"
        source_type  = "volume"
        boot_index = -1
        uuid = var.mdt_volume_id
    }

    # OST:
    block_device {
        destination_type = "volume"
        source_type  = "volume"
        boot_index = -1
        uuid = var.ost_volume_id
    }

}

resource "openstack_compute_instance_v2" "clients" {
  
  for_each = toset(var.clients)
  name = "${var.cluster_name}-${each.key}"
  image_name = var.client_image_name
  flavor_name = var.flavor_name
  key_pair = var.key_pair
  config_drive = true
  security_groups = ["default"]

  network {
    name = var.network_name
    access_network = true
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