[all:vars]
ansible_ssh_common_args= '-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

[servers]
${server.name} ansible_host=${[for n in server.network: n.fixed_ip_v4 if n.access_network][0]}

[clients]
%{ for client in clients ~}
${client.name} ansible_host=${[for n in client.network: n.fixed_ip_v4 if n.access_network][0]}
%{ endfor ~}

[ganesha]
%{ for client in clients ~}
%{ if length(regexall("ganesha", client.name)) > 0 ~}
${client.name}
%{ endif ~}
%{ endfor ~}
