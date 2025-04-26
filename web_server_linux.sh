#!bin/bash

apt-get update -y
apt-get upgrade -y

#Ansible
apt-get install software-properties-common -y
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible

#Git
apt-get install -y git

# Configurar SSH para que use el puerto 2222
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
ufw allow 2222
ufw --force enable
systemctl restart ssh