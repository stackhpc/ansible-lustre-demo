[all:vars]
ansible_ssh_common_args= '-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

[servers]
${cluster_name}-server ansible_host=${server.network[0].fixed_ip_v4}

[clients]
%{ for client in clients ~}
${client.name} ansible_host=${client.network[0].fixed_ip_v4}
%{ endfor ~}
