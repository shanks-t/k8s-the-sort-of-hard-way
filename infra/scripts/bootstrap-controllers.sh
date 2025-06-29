#!/bin/bash

# Kubernetes The Hard Way - Lab 08: Bootstrapping the Kubernetes Controllers
# This script runs on the controller node after binaries and config files have been copied from jumpbox
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md

set -e

echo "Bootstrapping Kubernetes Controllers on $(hostname)..."

# Verify we're on the controller node
if [[ "$(hostname)" != "controller" ]]; then
    echo "ERROR: This script must be run on the controller node"
    exit 1
fi

# Verify running as root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "Verified running as root on controller node"

# Create the Kubernetes configuration directory
echo "Creating Kubernetes configuration directory..."
mkdir -p /etc/kubernetes/config

# Install the Kubernetes Controller Binaries
echo "Installing Kubernetes Controller Binaries..."

mv kube-apiserver \
   kube-controller-manager \
   kube-scheduler kubectl \
   /usr/local/bin/

# Set executable permissions on binaries
chmod +x /usr/local/bin/kube-apiserver \
         /usr/local/bin/kube-controller-manager \
         /usr/local/bin/kube-scheduler \
         /usr/local/bin/kubectl

echo "✓ Kubernetes binaries moved to /usr/local/bin/ and made executable"

# Configure the Kubernetes API Server
echo "Configuring the Kubernetes API Server..."

mkdir -p /var/lib/kubernetes/

mv ca.crt ca.key \
   kube-api-server.key kube-api-server.crt \
   service-accounts.key service-accounts.crt \
   encryption-config.yaml \
   /var/lib/kubernetes/

mv kube-apiserver.service \
   /etc/systemd/system/kube-apiserver.service

echo "✓ API Server configured"

# Configure the Kubernetes Controller Manager
echo "Configuring the Kubernetes Controller Manager..."

mv kube-controller-manager.kubeconfig /var/lib/kubernetes/

mv kube-controller-manager.service /etc/systemd/system/

echo "✓ Controller Manager configured"

# Configure the Kubernetes Scheduler
echo "Configuring the Kubernetes Scheduler..."

mv kube-scheduler.kubeconfig /var/lib/kubernetes/

mv kube-scheduler.yaml /etc/kubernetes/config/

mv kube-scheduler.service /etc/systemd/system/

echo "✓ Scheduler configured"

# Start the Controller Services
echo "Starting the Controller Services..."

systemctl daemon-reload

systemctl enable kube-apiserver \
  kube-controller-manager kube-scheduler

systemctl start kube-apiserver \
  kube-controller-manager kube-scheduler

echo "✓ Controller services started"

# Allow up to 10 seconds for the Kubernetes API Server to fully initialize
echo "Waiting 10 seconds for the Kubernetes API Server to fully initialize..."
sleep 10

# Verification
echo "Performing verification..."

# Check service status with systemctl
echo "Checking service status..."
echo "kube-apiserver:"
systemctl is-active kube-apiserver

echo "kube-controller-manager:"
systemctl is-active kube-controller-manager

echo "kube-scheduler:"
systemctl is-active kube-scheduler

# Show detailed status
echo ""
echo "Detailed service status:"
systemctl status kube-apiserver --no-pager
echo ""
systemctl status kube-controller-manager --no-pager
echo ""
systemctl status kube-scheduler --no-pager

# Check logs with journalctl
echo ""
echo "Recent logs:"
journalctl -u kube-apiserver

# Test cluster-info
echo ""
echo "Testing kubectl cluster-info..."
kubectl cluster-info --kubeconfig admin.kubeconfig

echo ""
echo "=== RBAC for Kubelet Authorization ==="

# Apply the RBAC configuration (copied from jumpbox)
echo "Applying RBAC configuration..."
kubectl apply -f kube-apiserver-to-kubelet.yaml --kubeconfig admin.kubeconfig

echo ""
echo "=== Kubernetes Controllers Bootstrap Complete ==="
echo "✓ All controller services are running"
echo "✓ RBAC for kubelet authorization applied"
echo "✓ Cluster is ready for worker nodes"
