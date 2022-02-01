[all:vars]
ansible_ssh_common_args= '-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

[server]
${server.name} ansible_host=${[for n in server.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in server.network: net.name => net.fixed_ip_v4 })}'

[admin]
${admin.name} ansible_host=${[for n in admin.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in admin.network: net.name => net.fixed_ip_v4 })}'

[exporters]
${exporter.name} ansible_host=${[for n in exporter.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in exporter.network: net.name => net.fixed_ip_v4 })}'

[csd3]
${csd3.name} ansible_host=${[for n in csd3.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in csd3.network: net.name => net.fixed_ip_v4 })}'

[clients:children]
admin
exporters
csd3
