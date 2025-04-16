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

# Obtener el rol (web/sql) desde las etiquetas
ROLE=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Role" \
    --query "Tags[0].Value" --output text)

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
cat web_ips.txt >> inventory_web.ini

echo "[sql]" >> inventory_sql.ini
cat sql_ips.txt >> inventory_sql.ini

# Filtrar la IP de la propia máquina (para no incluirla en el inventario)
grep -v "$MY_IP" inventory_web.ini > temp_inventory.ini && mv temp_inventory.ini inventory_web.ini

sleep 30

grep -v "$MY_IP" inventory_sql.ini > temp_inventory.ini && mv temp_inventory.ini inventory_sql.ini

# Esperar 120 segundos (esto podría depender de tu caso específico)
sleep 120

# Ejecutar playbook correspondiente
if [ "$ROLE" == "web" ]; then
    ansible-playbook -i inventory_web.ini auto-config-web-server.yml --private-key /home/ubuntu/ssh-code.pem -e ansible_ssh_common_args='-o StrictHostKeyChecking=no'
elif [ "$ROLE" == "sql" ]; then
    ansible-playbook -i inventory_sql.ini auto-config-sql-server.yml --private-key /home/ubuntu/ssh-code.pem -e ansible_ssh_common_args='-o StrictHostKeyChecking=no'
else
    echo "Rol no reconocido o no definido. No se ejecutará ningún playbook."
fi