[webservers]
%{ for ip in ec2_public_ips ~}
${ip} ansible_user=ec2-user
%{ endfor ~}

[webservers:vars]
ansible_ssh_private_key_file=./deploy_key.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
