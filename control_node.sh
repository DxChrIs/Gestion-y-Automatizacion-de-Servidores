#!/bin/bash

#Instalacion de dependencias
apt-get update -y
apt-get upgrade -y

apt-get install software-properties-common -y
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible

apt-get install -y git
apt-get install -y nmap

#Clonar repositorio
cd /home/ubuntu
git clone https://github.com/DxChrIs/Gestion-y-Automatizacion-de-Servidores.git
cd Gestion-y-Automatizacion-de-Servidores

#Detectar direcciones IP de instancias VPC
MY_IP=$(hostname -I | awk '{print $1}')
nmap -sn 10.0.0.0/24 -oG - | awk '/Up$/{print $2}' > ip_list.txt
grep -v -e "$MY_IP" -e "10.0.0.0" -e "10.0.0.1" -e "10.0.0.2" ip_list.txt > active_ips.txt

#Identificar y crear inventarios
for ip in $(cat active_ips.txt); do
    ports=$(nmap -p 80,3306 --open $ip | grep -E "80/tcp|3306/tcp")

    if echo "$ports" | grep -q "80/tcp"; then
        echo "$ip ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/ssh-code.pem" >> web_server_host.ini
    elif echo "$ports" | grep -q "3306/tcp"; then
        echo "$ip ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/ssh-code.pem" >> sql_server_host.ini
    fi
done

#Ejecutar playbook
if [ -f web_server_host.ini ]; then
    ansible-playbook -i web_server_host.ini auto-config-web-server.yml
fi

if [ -f sql_server_host.ini ]; then
    ansible-playbook -i sql_server_host.ini auto-config-sql-server.yml
fi