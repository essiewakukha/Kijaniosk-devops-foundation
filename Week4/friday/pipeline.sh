#!/bin/bash

set -e

echo " Running Terraform..."
cd terraform
terraform apply -auto-approve

echo " Extracting IPs..."
IPS=$(terraform output -json servers_public_ip)

API_IP=$(echo $IPS | jq -r '.api')
LOGS_IP=$(echo $IPS | jq -r '.logs')
PAYMENTS_IP=$(echo $IPS | jq -r '.payments')

cd ..

echo " Creating Ansible inventory..."

cat > ansible/inventory.ini <<EOF
[kijanikiosk]
api ansible_host=$API_IP
logs ansible_host=$LOGS_IP
payments ansible_host=$PAYMENTS_IP

[kijanikiosk:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/terraform-key-new.pem
EOF

echo " Running Ansible..."

ansible-playbook -i ansible/inventory.ini ansible/kijanikiosk.yaml

echo " Pipeline completed successfully!"
