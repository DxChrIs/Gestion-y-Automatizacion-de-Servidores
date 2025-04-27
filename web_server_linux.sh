#!bin/bash

apt-get update -y
apt-get upgrade -y

#Ansible
apt-get install software-properties-common -y
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible

#Git
apt-get install -y git

sudo snap install amazon-ssm-agent --classic

sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

#habilitar firewall
ufw allow 22
ufw allow 80
ufw --force enable