#!/bin/bash

# Actualización e instalación de dependencias
apt-get update -y
apt-get upgrade -y
apt-get install -y software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible
apt-get install -y git
apt-get install -y nmap
apt-get install -y jq

# Asegúrate de tener AWS CLI instalado y configurado
sudo snap install aws-cli --classic

# Configuración de AWS CLI
aws configure set region us-east-1
aws configure set output json

# Obtener el ID de la instancia
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Clonar el repositorio de Git
cd /home/ubuntu
git clone https://github.com/DxChrIs/Gestion-y-Automatizacion-de-Servidores.git
cd Gestion-y-Automatizacion-de-Servidores

# Detectar la IP local de la instancia
MY_IP=$(hostname -I | awk '{print $1}')

# Obtener IPs de las instancias EC2 con etiquetas específicas (web y sql)
# Obtener IPs de las instancias con el tag 'Role: web'
aws ec2 describe-instances --filters "Name=tag:Role,Values=web" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text > web_ips.txt

# Obtener IPs de las instancias con el tag 'Role: sql'
aws ec2 describe-instances --filters "Name=tag:Role,Values=sql" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text > sql_ips.txt

# Combinar las IPs de web y sql en un solo archivo de inventario
echo "[web]" > inventory_web.ini
grep -v "$MY_IP" web_ips.txt | while read ip; do
    echo "$ip ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no' ansible_private_key_file=/home/ubuntu/ssh-code.pem" >> inventory_web.ini
done

echo "[sql]" > inventory_sql.ini
grep -v "$MY_IP" sql_ips.txt | while read ip; do
    echo "$ip ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no' ansible_private_key_file=/home/ubuntu/ssh-code.pem ansible_python_interpreter=/usr/bin/python3" >> inventory_sql.ini
done

# Esperar 120 segundos (esto podría depender de tu caso específico)
sleep 120

# Ejecutar playbook correspondiente
ansible-playbook -i inventory_web.ini auto-config-web-server.yml

sleep 60

ansible-playbook -i inventory_sql.ini auto-config-sql-server.yml