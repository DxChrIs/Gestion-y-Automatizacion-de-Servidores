#!bin/bash

apt-get update -y
apt-get upgrade -y

#Ansible
apt-get install software-properties-common -y
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible

#Git
apt-get install -y git