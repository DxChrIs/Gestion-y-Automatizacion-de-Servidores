#!/bin/bash

apt-get update -y
apt-get upgrade -y

apt-get install -y openssh-server

echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
systemctl restart sshd
echo "SSH server installed and configured to allow root login." >> /home/ubuntu/ssh_installation.txt