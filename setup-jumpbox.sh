#!/bin/bash

# Script to set up jumpbox with proper machine database
# Run this on the jumpbox after SSH'ing in

set -e

echo "Setting up Kubernetes The Hard Way jumpbox..."

# Install required packages if not already installed
echo "Installing required packages..."
apt-get update
apt-get -y install wget curl vim openssl git

# Create machines.txt with correct IP addresses
echo "Creating machines.txt file..."
cat > machines.txt << 'EOF'
10.240.0.10 server.kubernetes.local server
10.240.0.20 node-0.kubernetes.local node-0 10.200.0.0/24
10.240.0.21 node-1.kubernetes.local node-1 10.200.1.0/24
EOF

echo "machines.txt created with cluster nodes:"
cat machines.txt

# Generate hosts file
echo "Generating hosts file..."
echo "" > hosts
echo "# Kubernetes The Hard Way" >> hosts

while read IP FQDN HOST SUBNET; do
    ENTRY="${IP} ${FQDN} ${HOST}"
    echo $ENTRY >> hosts
done < machines.txt

echo "Generated hosts file:"
cat hosts

# Update local /etc/hosts
echo "Updating local /etc/hosts..."
cat hosts >> /etc/hosts

echo "Jumpbox machine database setup completed!"
echo ""
echo "To distribute hosts file to remote machines, run:"
echo "while read IP FQDN HOST SUBNET; do"
echo "  scp hosts root@\${HOST}:~/"
echo "  ssh root@\${HOST} \"cat hosts >> /etc/hosts\""
echo "done < machines.txt"