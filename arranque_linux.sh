#!/bin/bash

apt-get update -y
apt-get upgrade -y

apt-get install software-properties-common -y
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible
apt-get install -y openssh-server

apt-get install -y git

cd /home/ubuntu
git clone https://github.com/DxChrIs/Gestion-y-Automatizacion-de-Servidores.git

cd Gestion-y-Automatizacion-de-Servidores
ansible-playbook -i inventory/hosts auto-config-sql-server.yaml
echo "Ansible playbook executed successfully." >> /home/ubuntu/ansible_execution.txt



echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
systemctl restart sshd
echo "SSH server installed and configured to allow root login." >> /home/ubuntu/ssh_installation.txt