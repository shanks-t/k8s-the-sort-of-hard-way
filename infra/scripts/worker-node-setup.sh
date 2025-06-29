#!/bin/bash

# Kubernetes The Hard Way - Worker Node Setup
# This script configures a Kubernetes worker node with containerd, kubelet, and kube-proxy
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md

set -e

echo "Starting Kubernetes worker node setup..."

# Get hostname to identify which worker this is
HOSTNAME=$(hostname)
echo "Setting up worker node: $HOSTNAME"

# Verify all required files are present
echo "Verifying required files..."
required_files=(
    "crictl"
    "kube-proxy"
    "kubelet"
    "runc"
    "containerd"
    "containerd-shim-runc-v2"
    "containerd-stress"
    "kubectl"
    "10-bridge.conf"
    "99-loopback.conf"
    "kubelet-config.yaml"
    "kube-proxy-config.yaml"
    "containerd-config.toml"
    "containerd.service"
    "kubelet.service"
    "kube-proxy.service"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: Required file not found: $file"
        exit 1
    fi
    echo "✓ Found: $file"
done

# Verify CNI plugins directory
if [[ ! -d "cni-plugins" ]] || [[ -z "$(ls -A cni-plugins/)" ]]; then
    echo "ERROR: CNI plugins directory not found or empty"
    exit 1
fi
echo "✓ Found CNI plugins: $(ls cni-plugins/ | wc -l) plugins"

echo "All required files verified!"

# Step 1: Install dependencies
echo ""
echo "=== Step 1: Installing dependencies ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install socat conntrack ipset kmod

echo "✓ Dependencies installed"

# Step 2: Disable swap
echo ""
echo "=== Step 2: Disabling swap ==="
swapoff -a
echo "✓ Swap disabled"

# Step 3: Create installation directories
echo ""
echo "=== Step 3: Creating installation directories ==="
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes \
  /etc/containerd

echo "✓ Installation directories created"

# Step 4: Install binaries and set permissions
echo ""
echo "=== Step 4: Installing binaries ==="

# Set execute permissions on all binaries
chmod +x crictl kube-proxy kubelet runc containerd containerd-shim-runc-v2 containerd-stress kubectl
chmod +x cni-plugins/*

# Move worker binaries to /usr/local/bin/
mv crictl kube-proxy kubelet runc kubectl /usr/local/bin/

# Move containerd binaries to /bin/
mv containerd containerd-shim-runc-v2 containerd-stress /bin/

# Move CNI plugins to /opt/cni/bin/
mv cni-plugins/* /opt/cni/bin/

# Verify binary installation and permissions
echo "Verifying binary installation..."
for binary in crictl kube-proxy kubelet runc kubectl; do
    if command -v $binary &> /dev/null && [ -x "/usr/local/bin/$binary" ]; then
        echo "✓ $binary installed and executable"
    else
        echo "ERROR: $binary installation or permissions failed"
        ls -la "/usr/local/bin/$binary"
        exit 1
    fi
done

for binary in containerd containerd-shim-runc-v2 containerd-stress; do
    if [ -x "/bin/$binary" ]; then
        echo "✓ $binary installed and executable"
    else
        echo "ERROR: $binary installation or permissions failed"
        ls -la "/bin/$binary"
        exit 1
    fi
done

echo "✓ All binaries installed successfully"

# Step 5: Configure CNI Networking
echo ""
echo "=== Step 5: Configuring CNI Networking ==="

# Move CNI configuration files
mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/

# Load br_netfilter kernel module
modprobe br_netfilter

# Make kernel module persistent
echo "br_netfilter" >> /etc/modules-load.d/modules.conf

# Configure network settings
cat > /etc/sysctl.d/99-kubernetes-cri.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl settings
sysctl --system

echo "✓ CNI networking configured"

# Step 6: Configure containerd
echo ""
echo "=== Step 6: Configuring containerd ==="

# Move containerd configuration
mv containerd-config.toml /etc/containerd/config.toml

# Move containerd service file
mv containerd.service /etc/systemd/system/

echo "✓ containerd configured"

# Step 7: Configure kubelet
echo ""
echo "=== Step 7: Configuring kubelet ==="

# Move kubelet configuration
mv kubelet-config.yaml /var/lib/kubelet/

# Move kubelet service file
mv kubelet.service /etc/systemd/system/

echo "✓ kubelet configured"

# Step 8: Configure kube-proxy
echo ""
echo "=== Step 8: Configuring kube-proxy ==="

# Move kube-proxy configuration
mv kube-proxy-config.yaml /var/lib/kube-proxy/

# Move kube-proxy service file
mv kube-proxy.service /etc/systemd/system/

echo "✓ kube-proxy configured"

# Step 9: Start services
echo ""
echo "=== Step 9: Starting services ==="

# Reload systemd
systemctl daemon-reload

# Enable services
systemctl enable containerd kubelet kube-proxy

# Start services one by one with error checking
echo "Starting containerd..."
systemctl start containerd
sleep 3

if ! systemctl is-active --quiet containerd; then
    echo "ERROR: containerd failed to start"
    systemctl status containerd --no-pager
    journalctl -u containerd --no-pager -l --since "1 minute ago"
    exit 1
fi
echo "✓ containerd started successfully"

echo "Starting kubelet..."
systemctl start kubelet
sleep 3

if ! systemctl is-active --quiet kubelet; then
    echo "ERROR: kubelet failed to start"
    systemctl status kubelet --no-pager
    journalctl -u kubelet --no-pager -l --since "1 minute ago"
    exit 1
fi
echo "✓ kubelet started successfully"

echo "Starting kube-proxy..."
systemctl start kube-proxy
sleep 3

if ! systemctl is-active --quiet kube-proxy; then
    echo "ERROR: kube-proxy failed to start"
    systemctl status kube-proxy --no-pager
    journalctl -u kube-proxy --no-pager -l --since "1 minute ago"
    exit 1
fi
echo "✓ kube-proxy started successfully"

# Step 10: Verify services
echo ""
echo "=== Step 10: Verifying services ==="

# Wait for services to stabilize
echo "Waiting for services to stabilize..."
sleep 10

# Check all services
echo "Verifying all services are running..."
for service in containerd kubelet kube-proxy; do
    if systemctl is-active --quiet $service; then
        echo "✓ $service is running"
    else
        echo "ERROR: $service is not running"
        systemctl status $service --no-pager
        exit 1
    fi
done

# Test containerd
echo "Testing containerd..."
if ctr version &> /dev/null; then
    echo "✓ containerd is responding"
else
    echo "WARNING: containerd not responding to ctr commands"
fi

# Test kubelet (it may not be fully ready yet but should be running)
echo "Testing kubelet..."
if systemctl is-active --quiet kubelet; then
    echo "✓ kubelet service is active"
else
    echo "ERROR: kubelet service is not active"
    exit 1
fi

echo ""
echo "=== Worker Node Setup Complete ==="
echo "✓ Dependencies installed"
echo "✓ Swap disabled"
echo "✓ Directories created"
echo "✓ Binaries installed with correct permissions"
echo "✓ CNI networking configured"
echo "✓ containerd configured and running"
echo "✓ kubelet configured and running"
echo "✓ kube-proxy configured and running"
echo ""
echo "Worker node $HOSTNAME is ready!"
echo "Note: It may take a few minutes for the node to appear in 'kubectl get nodes'"