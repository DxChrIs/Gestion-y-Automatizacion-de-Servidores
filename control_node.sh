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

sleep 120

# Inicializar inventario
echo "[web]" > hosts.ini
web_found=false
echo "[db]" >> hosts.ini
db_found=false

# Identificar y clasificar hosts
for ip in $(cat active_ips.txt); do
    ports=$(nmap -p 80,3306 --open $ip | grep -E "80/tcp|3306/tcp")

    if echo "$ports" | grep -q "80/tcp"; then
        sed -i '/^\[db\]/i'"$ip ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/ssh-code.pem"'' hosts.ini
        web_found=true
    fi

    if echo "$ports" | grep -q "3306/tcp"; then
        echo "$ip ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/ssh-code.pem" >> hosts.ini
        db_found=true
    fi
done

# Ejecutar playbooks por grupo
if $web_found; then
    ansible-playbook -i hosts.ini -l web auto-config-web-server.yml
fi

if $db_found; then
    ansible-playbook -i hosts.ini -l db auto-config-sql-server.yml
fi