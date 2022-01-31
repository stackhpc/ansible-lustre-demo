terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

variable "cluster_name" {}
variable "project_name" {}
variable "exporter_image_name" {}
variable "exporter_flavor_name" {}
variable "key_pair" {}
variable "admin_network_name" {}
variable "rdma_network_name" {}
variable "project_cidr" {
  default = "192.168.0.0/24"
}
variable "exporter_ip" {
  default = "192.168.0.4"
}

resource "openstack_networking_network_v2" "project" {
  name = var.project_name
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "project" {
  name = var.project_name
  network_id = "${openstack_networking_network_v2.project.id}"
  cidr       = var.project_cidr
  ip_version = 4
}

module "exporter" {
  source = "../rdma-host"

  name = "${var.cluster_name}-${var.project_name}-exporter"
  image_name = var.exporter_image_name
  flavor_name = var.exporter_flavor_name
  key_pair = var.key_pair
  network_name = var.admin_network_name
  rdma_network_name = var.rdma_network_name
}

resource "openstack_compute_interface_attach_v2" "project" {
  instance_id = module.exporter.host.id
  network_id  = openstack_networking_network_v2.project.id
  fixed_ip    = var.exporter_ip
}
