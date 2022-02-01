[all:vars]
ansible_ssh_common_args= '-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

[nfs_client]
${client.name} ansible_host=${[for n in client.network: n.fixed_ip_v4 if n.access_network][0]} networks='${jsonencode({for net in client.network: net.name => net.fixed_ip_v4 })}'
