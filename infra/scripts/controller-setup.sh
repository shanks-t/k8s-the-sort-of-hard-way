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

# Save etcd setup script
echo "Installing etcd setup script..."
if curl -f -H "Metadata-Flavor: Google" \
   "http://metadata.google.internal/computeMetadata/v1/instance/attributes/etcd-setup-script" \
   -o /root/etcd-setup.sh 2>/dev/null; then
    chmod +x /root/etcd-setup.sh
    echo "✓ etcd setup script installed at /root/etcd-setup.sh"
else
    echo "ERROR: Failed to retrieve etcd setup script from metadata"
fi

echo "Controller setup completed"