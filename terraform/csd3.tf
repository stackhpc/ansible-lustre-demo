# Models a CSD Lustre client
resource "openstack_networking_port_v2" "csd3_client" {
  
  name = "lustre-csd-client"
  network_id = data.openstack_networking_network_v2.lustre_net.id
  admin_state_up = "true"

  binding {
    vnic_type = "direct"
  }

}

resource "openstack_compute_instance_v2" "csd3_client" {

    name = "lustre-csd-client"
    image_name = var.admin_image_name
    flavor_name = var.admin_flavor_name
    key_pair = var.key_pair
    config_drive = true
    security_groups = var.security_groups

    network {
      port = openstack_networking_port_v2.csd3_client.id
      access_network = true
    }

}
