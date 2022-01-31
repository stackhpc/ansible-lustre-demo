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
variable "server_flavor_name" {}
variable "admin_image_name" {}
variable "admin_flavor_name" {}
variable "projects" {
  type = list(string)
}
variable "exporter_image_name" {}
variable "exporter_flavor_name" {}
variable "key_pair" {}
variable "admin_network_name" {}
variable "rdma_network_name" {}

module "server" {
  source = "../modules/rdma-host"

  name = "${var.cluster_name}-lustre-server"
  image_name = var.server_image_name
  flavor_name = var.server_flavor_name
  key_pair = var.key_pair
  network_name = var.admin_network_name
  rdma_network_name = var.rdma_network_name
}

module "admin" {
  source = "../modules/rdma-host"

  name = "${var.cluster_name}-lustre-admin"
  image_name = var.admin_image_name
  flavor_name = var.admin_flavor_name
  key_pair = var.key_pair
  network_name = var.admin_network_name
  rdma_network_name = var.rdma_network_name
}

# project
resource "openstack_networking_network_v2" "network_1" {
  name           = "network_1"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet_1" {
  name       = "subnet_1"
  network_id = "${openstack_networking_network_v2.network_1.id}"
  cidr       = "192.168.199.0/24"
  ip_version = 4
}

module "project" {
  source = "../modules/project"

  for_each = toset(var.projects)

  cluster_name = var.cluster_name
  project_name = each.key
  exporter_image_name = var.exporter_image_name
  exporter_flavor_name = var.exporter_flavor_name
  key_pair = var.key_pair
  admin_network_name = var.admin_network_name
  rdma_network_name = var.rdma_network_name
}

resource "local_file" "hosts" {
  content = templatefile("${path.module}/inventory.tpl",
    {
      "cluster_name" : var.cluster_name
      "server" : module.server,
      "admin" : module.admin,
      "exporters" : module.project,
    },
  )
  filename = "${path.module}/../../inventory/hosts"
}
