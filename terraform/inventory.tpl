[all:vars]
ansible_ssh_common_args= '-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

[lustre_server]
${server.name} ansible_host=${[for n in server.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in server.network: net.name => net.fixed_ip_v4 })}'

[lustre_admin]
${admin.name} ansible_host=${[for n in admin.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in admin.network: net.name => net.fixed_ip_v4 })}'

[lustre_exporters]
${exporter.name} ansible_host=${[for n in exporter.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in exporter.network: net.name => net.fixed_ip_v4 })}'

[lustre_csd3]
${csd3.name} ansible_host=${[for n in csd3.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in csd3.network: net.name => net.fixed_ip_v4 })}'

[nfs_clients]
${demo_nfs_client.name} ansible_host=${[for n in demo_nfs_client.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in demo_nfs_client.network: net.name => net.fixed_ip_v4 })}'

[lustre_clients:children]
lustre_admin
lustre_exporters
lustre_csd3

[lustre:children]
lustre_server
lustre_clients
