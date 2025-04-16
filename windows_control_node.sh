#!/bin/bash

#Actualizacion e instalacion de dependencias
apt-get update -y
apt-get upgrade -y
apt-get install -y software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible
apt-get install -y git
apt-get install -y python3-pip
apt-get install -y jq
pip3 install pywinrm boto3 botocore

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

# Obtener IPs de las instancias EC2 con etiquetas específicas (web, ad, file)
#IIS
aws ec2 describe-instances --filters "Name=tag:Role,Values=iis" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text > iis_ips.txt

#AD
aws ec2 describe-instances --filters "Name=tag:Role,Values=ad" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text > ad_ips.txt

#File
aws ec2 describe-instances --filters "Name=tag:Role,Values=file" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text > file_ips.txt

# Combinar las IPs de web y sql en un solo archivo de inventario
echo "[iis]" > inventory_iis.ini
grep -v "$MY_IP" iis_ips.txt | while read ip; do
    echo "$ip ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no' ansible_private_key_file=/home/ubuntu/ssh-code.pem" >> inventory_iis.ini
done

echo "[sql]" > inventory_sql.ini
grep -v "$MY_IP" sql_ips.txt | while read ip; do
    echo "$ip ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no' ansible_private_key_file=/home/ubuntu/ssh-code.pem" >> inventory_sql.ini
done