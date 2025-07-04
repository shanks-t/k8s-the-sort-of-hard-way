#!/bin/bash

# Worker-specific setup script template
# Sets hostname and prepares for Kubernetes worker node

set -e

WORKER_INDEX="${worker_index}"

echo "Starting worker-$WORKER_INDEX specific setup..."

# Set hostname for worker node (must match certificate name)
hostnamectl set-hostname "node-$WORKER_INDEX"
sed -i '/^127.0.1.1/d' /etc/hosts
echo "127.0.1.1 node-$WORKER_INDEX node-$WORKER_INDEX.kubernetes.local worker-$WORKER_INDEX" >> /etc/hosts

# Restart hostname service
systemctl restart systemd-hostnamed

# Enable IP forwarding for Kubernetes
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Load required kernel modules for container runtime
modprobe overlay
modprobe br_netfilter

# Make modules persistent
cat << EOF >> /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

echo "Worker-$WORKER_INDEX setup completed"