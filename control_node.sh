#!/bin/bash
sudo su
# Actualización e instalación de dependencias
apt-get update -y
apt-get upgrade -y
apt-get install -y software-properties-common
add-apt-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible
apt-get install -y git
apt-get install -y nmap

# Asegúrate de tener AWS CLI instalado y configurado
apt-get install awscli -y

# Configuración de AWS CLI
aws configure set region us-east-1
aws configure set output json

# Clonar el repositorio de Git
cd /home/ubuntu
git clone https://github.com/DxChrIs/Gestion-y-Automatizacion-de-Servidores.git
cd Gestion-y-Automatizacion-de-Servidores

# Detectar la IP local de la instancia
MY_IP=$(hostname -I | awk '{print $1}')

# Obtener IPs de las instancias EC2 con etiquetas específicas (web y sql)
# Obtener IPs de las instancias con el tag 'Role: web'
aws ec2 describe-instances --filters "Name=tag:Role,Values=web" --query "Reservations[*].Instances[*].PublicIpAddress" --output text > web_ips.txt

# Obtener IPs de las instancias con el tag 'Role: sql'
aws ec2 describe-instances --filters "Name=tag:Role,Values=sql" --query "Reservations[*].Instances[*].PublicIpAddress" --output text > sql_ips.txt

# Combinar las IPs de web y sql en un solo archivo de inventario
echo "[web]" > inventory.ini
cat web_ips.txt >> inventory.ini

echo "[sql]" >> inventory.ini
cat sql_ips.txt >> inventory.ini

# Filtrar la IP de la propia máquina (para no incluirla en el inventario)
grep -v "$MY_IP" inventory.ini > temp_inventory.ini && mv temp_inventory.ini inventory.ini

# Esperar 120 segundos (esto podría depender de tu caso específico)
echo "Esperando 120 segundos..."
sleep 120

echo "Inventario creado exitosamente: inventory.ini"