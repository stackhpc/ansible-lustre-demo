[all:vars]
ansible_ssh_common_args= '-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

[servers]
${server.name} ansible_host=${server.network[0].fixed_ip_v4}

[clients]
%{ for client in clients ~}
${client.name} ansible_host=${client.network[0].fixed_ip_v4}
%{ endfor ~}

[ganesha]
%{ for client in clients ~}
%{ if length(regexall("ganesha", client.name)) > 0 ~}
${client.name} ansible_host=${client.network[0].fixed_ip_v4}
%{ endif ~}
%{ endfor ~}
