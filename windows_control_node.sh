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
aws ec2 describe-instances --filters "Name=tag:Role,Values=iis" --query "Reservations[*].Instances[*].PrivateDnsName" --output text > iis_ips.txt

#AD
aws ec2 describe-instances --filters "Name=tag:Role,Values=ad" --query "Reservations[*].Instances[*].PrivateDnsName" --output text > ad_ips.txt

#File
aws ec2 describe-instances --filters "Name=tag:Role,Values=file" --query "Reservations[*].Instances[*].PrivateDnsName" --output text > file_ips.txt

# === Crear archivo de inventario Windows para Ansible + WinRM ===
echo "[windows]" > inventory_iis.ini; echo "[windows]" > inventory_ad.ini; echo "[windows]" > inventory_file.ini
cat iis_ips.txt | grep -v "$MY_IP" >> inventory_iis.ini
cat ad_ips.txt | grep -v "$MY_IP" >> inventory_ad.ini
cat file_ips.txt | grep -v "$MY_IP" >> inventory_file.ini

cat <<EOL >> inventory_iis.ini

[windows:vars]
ansible_user=Administrator
ansible_password="ElAdmin12345"
ansible_port=5985
ansible_connection=winrm
ansible_winrm_transport=basic
ansible_winrm_server_cert_validation=ignore
ansible_winrm_scheme=http
ansible_winrm_kerberos_delegation=true
EOL

cat <<EOL >> inventory_ad.ini

[windows:vars]
ansible_user=Administrator
ansible_password="ElAdmin12345"
ansible_port=5985
ansible_connection=winrm
ansible_winrm_transport=basic
ansible_winrm_server_cert_validation=ignore
ansible_winrm_scheme=http
ansible_winrm_kerberos_delegation=true
EOL

cat <<EOL >> inventory_file.ini

[windows:vars]
ansible_user=Administrator
ansible_password="ElAdmin12345"
ansible_port=5985
ansible_connection=winrm
ansible_winrm_transport=basic
ansible_winrm_server_cert_validation=ignore
ansible_winrm_scheme=http
ansible_winrm_kerberos_delegation=true
EOL

#Wait 120 seconds
sleep 120

# === Ejecutar playbook según el rol ===
ansible-playbook -i inventory_iis.ini auto-config-windows-iis.yml

ansible-playbook -i inventory_ad.ini auto-config-windows-ad.yml

ansible-playbook -i inventory_file.ini auto-config-windows-file-server.yml