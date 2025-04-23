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

#Ansible Galaxy Collection Windows.ad
ansible-galaxy collection install microsoft.ad --force
ansible-galaxy collection install community.windows --force

# Clonar el repositorio de Git
cd /home/ubuntu
git clone https://github.com/DxChrIs/Gestion-y-Automatizacion-de-Servidores.git
cd Gestion-y-Automatizacion-de-Servidores

# Obtener el ID de la instancia
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PEM_KEY_PATH="/home/ubuntu/ssh-code.pem"

# Detectar la IP local de la instancia
MY_IP=$(hostname -I | awk '{print $1}')

sleep 120

# Obtener la ID de la instancia IIS (puedes hacer esto con AD y FILE igual)
INSTANCE_ID_IIS=$(aws ec2 describe-instances --filters "Name=tag:Role,Values=iis" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

INSTANCE_ID_AD=$(aws ec2 describe-instances --filters "Name=tag:Role,Values=ad" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

INSTANCE_ID_FILE=$(aws ec2 describe-instances --filters "Name=tag:Role,Values=file" "Name=instance-state-name,Values=running"\
  --query "Reservations[0].Instances[0].InstanceId" --output text)

# Obtener la contraseña de administrador usando AWS CLI y OpenSSL
ADMIN_PASSWORD_IIS=$(aws ec2 get-password-data \
  --instance-id "$INSTANCE_ID_IIS" \
  --priv-launch-key "$PEM_KEY_PATH" \
  --query 'PasswordData' \
  --output text)

ADMIN_PASSWORD_AD=$(aws ec2 get-password-data \
  --instance-id "$INSTANCE_ID_AD" \
  --priv-launch-key "$PEM_KEY_PATH" \
  --query 'PasswordData' \
  --output text)

ADMIN_PASSWORD_FILE=$(aws ec2 get-password-data \
  --instance-id "$INSTANCE_ID_FILE" \
  --priv-launch-key "$PEM_KEY_PATH" \
  --query 'PasswordData' \
  --output text)

# Obtener IPs de las instancias EC2 con etiquetas específicas (iis, ad, file)
#IIS
aws ec2 describe-instances --filters "Name=tag:Role,Values=iis" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PrivateDnsName" --output text > iis_ips.txt
#AD
aws ec2 describe-instances --filters "Name=tag:Role,Values=ad" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PrivateDnsName" --output text > ad_ips.txt
#File
aws ec2 describe-instances --filters "Name=tag:Role,Values=file" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PrivateDnsName" --output text > file_ips.txt

# === Crear archivo de inventario Windows para Ansible + WinRM ===
# IIS
{
  echo "[windows]"
  grep -v "$MY_IP" iis_ips.txt
  echo ""
  cat <<EOL
[windows:vars]
ansible_user=Administrator
ansible_password="$ADMIN_PASSWORD_IIS"
ansible_port=5985
ansible_connection=winrm
ansible_winrm_transport=basic
ansible_winrm_server_cert_validation=ignore
ansible_winrm_scheme=http
EOL
} > inventory_iis.ini

# AD
{
  echo "[windows]"
  grep -v "$MY_IP" ad_ips.txt
  echo ""
  cat <<EOL
[windows:vars]
ansible_user=Administrator
ansible_password="$ADMIN_PASSWORD_AD"
ansible_port=5985
ansible_connection=winrm
ansible_winrm_transport=basic
ansible_winrm_server_cert_validation=ignore
ansible_winrm_scheme=http
EOL
} > inventory_ad.ini

# FILE
{
  echo "[windows]"
  grep -v "$MY_IP" file_ips.txt
  echo ""
  cat <<EOL
[windows:vars]
ansible_user=Administrator
ansible_password="$ADMIN_PASSWORD_FILE"
ansible_port=5985
ansible_connection=winrm
ansible_winrm_transport=basic
ansible_winrm_server_cert_validation=ignore
ansible_winrm_scheme=http
EOL
} > inventory_file.ini

sleep 120

# === Ejecutar playbook según el rol ===
ansible-playbook -i inventory_iis.ini auto-config-windows-iis.yml

sleep 180

ansible-playbook -i inventory_ad.ini auto-config-windows-ad.yml

sleep 180

ansible-playbook -i inventory_file.ini auto-config-windows-file-server.yml