#!/bin/bash

# Controller-specific setup script
# Sets hostname and prepares for Kubernetes control plane

set -e

echo "Starting controller-specific setup..."

# Set hostname for controller
hostnamectl set-hostname controller
sed -i '/^127.0.1.1/d' /etc/hosts
echo "127.0.1.1 controller server.kubernetes.local" >> /etc/hosts

# Restart hostname service
systemctl restart systemd-hostnamed

# Enable IP forwarding for Kubernetes
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

echo "Controller setup completed"