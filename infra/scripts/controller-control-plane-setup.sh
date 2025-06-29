#!/bin/bash

# Kubernetes The Hard Way - Controller Control Plane Setup
# This script configures the Kubernetes control plane on the controller node
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md

set -e

echo "Starting Kubernetes control plane setup on controller..."

# Get internal IP address
INTERNAL_IP=$(hostname -I | awk '{print $1}')
echo "Using internal IP: $INTERNAL_IP"

# Verify all required files are present
echo "Verifying required files..."
required_files=(
    "kube-apiserver"
    "kube-controller-manager" 
    "kube-scheduler"
    "kubectl"
    "ca.crt"
    "ca.key"
    "kube-api-server.key"
    "kube-api-server.crt"
    "service-accounts.key"
    "service-accounts.crt"
    "encryption-config.yaml"
    "kube-controller-manager.kubeconfig"
    "kube-scheduler.kubeconfig"
    "kube-apiserver.service"
    "kube-controller-manager.service"
    "kube-scheduler.service"
    "kube-scheduler.yaml"
    "kube-apiserver-to-kubelet.yaml"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: Required file not found: $file"
        exit 1
    fi
    echo "✓ Found: $file"
done

echo "All required files verified!"

# Step 1: Create Kubernetes configuration directory
echo "Creating Kubernetes configuration directory..."
mkdir -p /etc/kubernetes/config

# Step 2: Install Kubernetes Controller Binaries
echo "Installing Kubernetes controller binaries..."
mv kube-apiserver \
   kube-controller-manager \
   kube-scheduler kubectl \
   /usr/local/bin/

# Set executable permissions on all binaries
echo "Setting executable permissions on binaries..."
chmod +x /usr/local/bin/kube-apiserver \
         /usr/local/bin/kube-controller-manager \
         /usr/local/bin/kube-scheduler \
         /usr/local/bin/kubectl

# Verify binary installation and permissions
echo "Verifying binary installation and permissions..."
for binary in kube-apiserver kube-controller-manager kube-scheduler kubectl; do
    if command -v $binary &> /dev/null && [ -x "/usr/local/bin/$binary" ]; then
        echo "✓ $binary installed and executable"
    else
        echo "ERROR: $binary installation or permissions failed"
        ls -la "/usr/local/bin/$binary"
        exit 1
    fi
done

# Step 3: Configure Kubernetes API Server
echo "Configuring Kubernetes API Server..."

# Create kubernetes directory and move certificates and encryption config
mkdir -p /var/lib/kubernetes/

mv ca.crt ca.key \
   kube-api-server.key kube-api-server.crt \
   service-accounts.key service-accounts.crt \
   encryption-config.yaml \
   /var/lib/kubernetes/

# Move API server service file
mv kube-apiserver.service \
   /etc/systemd/system/kube-apiserver.service

echo "✓ API Server configured"

# Step 4: Configure Kubernetes Controller Manager
echo "Configuring Kubernetes Controller Manager..."

mv kube-controller-manager.kubeconfig /var/lib/kubernetes/

mv kube-controller-manager.service /etc/systemd/system/

echo "✓ Controller Manager configured"

# Step 5: Configure Kubernetes Scheduler
echo "Configuring Kubernetes Scheduler..."

mv kube-scheduler.kubeconfig /var/lib/kubernetes/

mv kube-scheduler.yaml /etc/kubernetes/config/

mv kube-scheduler.service /etc/systemd/system/

echo "✓ Scheduler configured"

# Step 6: Start Controller Services
echo "Starting Kubernetes control plane services..."

systemctl daemon-reload

systemctl enable kube-apiserver \
  kube-controller-manager kube-scheduler

# Start services one by one with error checking
echo "Starting kube-apiserver..."
systemctl start kube-apiserver
sleep 5

# Check if API server started successfully
if ! systemctl is-active --quiet kube-apiserver; then
    echo "ERROR: kube-apiserver failed to start"
    systemctl status kube-apiserver --no-pager
    journalctl -u kube-apiserver --no-pager -l --since "1 minute ago"
    exit 1
fi

echo "Starting kube-controller-manager..."
systemctl start kube-controller-manager
sleep 3

echo "Starting kube-scheduler..."
systemctl start kube-scheduler
sleep 3

# Wait for services to stabilize
echo "Waiting for services to stabilize..."
sleep 10

# Verify services are running
echo "Verifying control plane services..."
for service in kube-apiserver kube-controller-manager kube-scheduler; do
    if systemctl is-active --quiet $service; then
        echo "✓ $service is running"
    else
        echo "ERROR: $service is not running"
        systemctl status $service
        exit 1
    fi
done

# Check API server health
echo "Checking API server health..."
if curl -k https://127.0.0.1:6443/healthz &> /dev/null; then
    echo "✓ API server health check passed"
else
    echo "WARNING: API server health check failed (may need more time to initialize)"
fi

echo "=== Kubernetes Control Plane Setup Complete ==="
echo "✓ Kubernetes binaries installed in /usr/local/bin/"
echo "✓ Certificates and encryption config in /var/lib/kubernetes/"
echo "✓ Configuration files in /etc/kubernetes/config/"
echo "✓ systemd services created and started"
echo "✓ kube-apiserver: $(systemctl is-active kube-apiserver)"
echo "✓ kube-controller-manager: $(systemctl is-active kube-controller-manager)"
echo "✓ kube-scheduler: $(systemctl is-active kube-scheduler)"
echo ""
echo "Next step: Configure RBAC permissions"
echo "Run: kubectl apply -f kube-apiserver-to-kubelet.yaml --kubeconfig admin.kubeconfig"