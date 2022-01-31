[all:vars]
ansible_ssh_common_args= '-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

[server]
${server.name} ansible_host=${[for n in server.host.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in server.host.network: net.name => net.fixed_ip_v4 })}'

[admin]
${admin.name} ansible_host=${[for n in admin.host.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in admin.host.network: net.name => net.fixed_ip_v4 })}'

[exporters]
%{ for exporter in exporters ~}
${exporter.name} ansible_host=${[for n in exporter.host.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in exporter.host.network: net.name => net.fixed_ip_v4 })}'
%{ endfor ~}
