terraform {
  required_version = ">= 0.14"
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

# lustre server:
variable "server_image_name" {
  default = "CentOS-7-x86_64-GenericCloud-2009"
}
variable "server_flavor_name" {
  default = "vm.iris.cpu.dac.half"
}
# admin client:
variable "admin_image_name" {
  default = "RockyLinux-8.5-20211114.2"
}
variable "admin_flavor_name" {
  default = "vm.alaska.cpu.general.small"
}
# lustre->nfs exporter:
variable "exporter_image_name" {
  default = "RockyLinux-8.5-20211114.2"
}
variable "exporter_flavor_name" {
  default = "vm.alaska.cpu.general.small"
}
variable "exporter_network_name" {
  default = "portal-internal"
}
variable "exporter_subnet_name" {
  default = "portal-internal"
}
variable "exporter_ip" {
  default = "192.168.3.4"
}

# all:
variable "key_pair" {
  default = "steveb-rcp-cloud-portal-demo-deploy-v1"
}
variable "lustre_network_name" {
  default = "WCDC-iLab-60"
}

variable "security_groups" {
  default = ["default"]
}

data "openstack_networking_network_v2" "lustre_net" {
  name = var.lustre_network_name
}

data "openstack_networking_network_v2" "exporter_net" {
  name = var.exporter_network_name
}

data "openstack_networking_subnet_v2" "exporter_subnet" {
  name = var.exporter_subnet_name
}

resource "openstack_networking_port_v2" "server" {
  
  name = "lustre-server"
  network_id = data.openstack_networking_network_v2.lustre_net.id
  admin_state_up = "true"

  binding {
    vnic_type = "direct"
  }

}

resource "openstack_compute_instance_v2" "server" {

    name = "lustre-server"
    image_name = var.server_image_name
    flavor_name = var.server_flavor_name
    key_pair = var.key_pair
    config_drive = true
    security_groups = var.security_groups

    network {
      port = openstack_networking_port_v2.server.id
      access_network = true
    }

}

resource "openstack_networking_port_v2" "admin" {
  
  name = "lustre-admin"
  network_id = data.openstack_networking_network_v2.lustre_net.id
  admin_state_up = "true"

  binding {
    vnic_type = "direct"
  }

}

resource "openstack_compute_instance_v2" "admin" {

    name = "lustre-admin"
    image_name = var.admin_image_name
    flavor_name = var.admin_flavor_name
    key_pair = var.key_pair
    config_drive = true
    security_groups = var.security_groups

    network {
      port = openstack_networking_port_v2.admin.id
      access_network = true
    }

}

resource "openstack_networking_port_v2" "exporter" {
  
  name = "lustre-exporter"
  network_id = data.openstack_networking_network_v2.lustre_net.id
  admin_state_up = "true"

  binding {
    vnic_type = "direct"
  }

}

resource "openstack_networking_port_v2" "nfs" {
  
  name = "lustre-exporter-nfs"
  network_id = data.openstack_networking_network_v2.exporter_net.id
  admin_state_up = "true"
  tags = ["nfs:lustre"] # TODO: maybe we need to add the fs name or something into here?
  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.exporter_subnet.id
    ip_address = var.exporter_ip
  }

}

resource "openstack_compute_instance_v2" "exporter" {

    name = "lustre-exporter"
    image_name = var.exporter_image_name
    flavor_name = var.exporter_flavor_name
    key_pair = var.key_pair
    config_drive = true
    security_groups = var.security_groups

    network {
      port = openstack_networking_port_v2.exporter.id
      access_network = true
    }

    network {
        port = openstack_networking_port_v2.nfs.id
    }

}

resource "local_file" "hosts" {
  content = templatefile("${path.module}/inventory.tpl",
    {
      "server" : openstack_compute_instance_v2.server,
      "admin" : openstack_compute_instance_v2.admin,
      "exporter" : openstack_compute_instance_v2.exporter,
      "csd3": openstack_compute_instance_v2.csd3_client,
    },
  )
  filename = "${path.module}/../inventory/hosts"
}
