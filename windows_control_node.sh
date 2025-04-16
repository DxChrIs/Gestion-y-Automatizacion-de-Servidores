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

# Clonar el repositorio de Git
cd /home/ubuntu
git clone https://github.com/DxChrIs/Gestion-y-Automatizacion-de-Servidores.git
cd Gestion-y-Automatizacion-de-Servidores

# Obtener el ID de la instancia
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
# Detectar la IP local de la instancia
MY_IP=$(hostname -I | awk '{print $1}')

# Obtener IPs de las instancias EC2 con etiquetas específicas (web, ad, file)
#IIS
aws ec2 describe-instances --filters "Name=tag:Role,Values=iis" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text > iis_ips.txt

#AD
aws ec2 describe-instances --filters "Name=tag:Role,Values=ad" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text > ad_ips.txt

#File
aws ec2 describe-instances --filters "Name=tag:Role,Values=file" --query "Reservations[*].Instances[*].PrivateIpAddress" --output text > file_ips.txt

# === Crear archivo de inventario Windows para Ansible + WinRM ===
echo "[windows]" > inventory_windows.ini
cat iis_ips.txt ad_ips.txt file_ips.txt | grep -v "$MY_IP" >> inventory_windows.ini

cat <<EOL >> inventory_windows.ini

[windows:vars]
ansible_user=Administrator
ansible_password=Chris1853
ansible_port=5985
ansible_connection=winrm
ansible_winrm_transport=basic
ansible_winrm_server_cert_validation=ignore
EOL

# === Obtener el rol actual desde la instancia ===
ROLE=$(aws ec2 describe-tags \
  --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Role" \
  --query "Tags[0].Value" --output text)

# === Ejecutar playbook según el rol ===
case "$ROLE" in
  "iis")
    echo "Iniciando configuración para servidor IIS..."
    ansible-playbook -i inventory_windows.ini windows-iis.yml
    ;;
  "ad")
    echo "Iniciando configuración para Active Directory..."
    ansible-playbook -i inventory_windows.ini windows-ad.yml
    ;;
  "file")
    echo "Iniciando configuración para File Server..."
    ansible-playbook -i inventory_windows.ini windows-file-server.yml
    ;;
  *)
    echo "Rol no reconocido o no definido. No se ejecutará ningún playbook."
    ;;
esac