#!/bin/bash

# Kubernetes The Hard Way - Controller Binaries Distribution
# This script copies Kubernetes control plane binaries and config files to the controller node
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md

set -e

echo "Starting Kubernetes controller binaries and config distribution..."

# Verify we're in the correct directory
if [[ ! -d "/root/kubernetes-the-hard-way" ]]; then
    echo "ERROR: kubernetes-the-hard-way directory not found"
    exit 1
fi

cd /root/kubernetes-the-hard-way

# Verify required binaries exist
echo "Verifying controller binaries..."
required_binaries=(
    "downloads/controller/kube-apiserver"
    "downloads/controller/kube-controller-manager"
    "downloads/controller/kube-scheduler"
    "downloads/client/kubectl"
)

for binary in "${required_binaries[@]}"; do
    if [[ ! -f "$binary" ]]; then
        echo "ERROR: Required binary not found: $binary"
        exit 1
    fi
    echo "✓ Found: $binary"
done

# Verify required service files exist
echo "Verifying systemd service files..."
required_services=(
    "units/kube-apiserver.service"
    "units/kube-controller-manager.service"
    "units/kube-scheduler.service"
)

for service in "${required_services[@]}"; do
    if [[ ! -f "$service" ]]; then
        echo "ERROR: Required service file not found: $service"
        exit 1
    fi
    echo "✓ Found: $service"
done

# Verify required config files exist
echo "Verifying configuration files..."
required_configs=(
    "configs/kube-scheduler.yaml"
    "configs/kube-apiserver-to-kubelet.yaml"
)

for config in "${required_configs[@]}"; do
    if [[ ! -f "$config" ]]; then
        echo "ERROR: Required config file not found: $config"
        exit 1
    fi
    echo "✓ Found: $config"
done

echo "All required files verified!"

# Ensure binary files have execute permissions before copying
echo "Setting execute permissions on binary files..."
chmod +x downloads/controller/kube-apiserver \
         downloads/controller/kube-controller-manager \
         downloads/controller/kube-scheduler \
         downloads/client/kubectl

# Copy all required files to controller as per tutorial
echo "Copying Kubernetes control plane files to controller..."
scp \
  downloads/controller/kube-apiserver \
  downloads/controller/kube-controller-manager \
  downloads/controller/kube-scheduler \
  downloads/client/kubectl \
  units/kube-apiserver.service \
  units/kube-controller-manager.service \
  units/kube-scheduler.service \
  configs/kube-scheduler.yaml \
  configs/kube-apiserver-to-kubelet.yaml \
  root@server:~/

echo "✓ All files copied to controller"

# Verify files were copied successfully
echo "Verifying files on controller..."
ssh root@server 'ls -la ~/kube-* ~/kubectl'

echo "=== Controller Files Distribution Complete ==="
echo "✓ kube-apiserver binary and service copied"
echo "✓ kube-controller-manager binary and service copied"
echo "✓ kube-scheduler binary, service, and config copied"
echo "✓ kubectl client binary copied"
echo "✓ kube-apiserver-to-kubelet RBAC config copied"
echo ""
echo "Next step: Run controller-control-plane-setup.sh on the controller node"