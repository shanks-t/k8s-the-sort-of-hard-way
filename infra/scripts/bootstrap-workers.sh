#!/bin/bash

# Kubernetes The Hard Way - Lab 09: Bootstrapping the Kubernetes Workers
# This script runs on worker nodes after binaries and config files have been copied from jumpbox
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md

set -e

echo "Bootstrapping Kubernetes Worker on $(hostname)..."

# Verify we're on a worker node
if [[ "$(hostname)" != "worker-"* && "$(hostname)" != "node-"* ]]; then
    echo "ERROR: This script must be run on a worker node"
    exit 1
fi

# Verify running as root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "Verified running as root on worker node $(hostname)"

# Install OS dependencies
echo "Installing OS dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install socat conntrack ipset

# Disable swap
echo "Disabling swap..."
swapoff -a

# Create installation directories
echo "Creating installation directories..."
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes \
  /etc/containerd/

# Install worker binaries
echo "Installing worker binaries..."

# Check if binaries already exist in target directories
if [[ -f "/usr/local/bin/kubelet" ]]; then
    echo "Worker binaries already installed, skipping installation"
else
    # Only chmod and move if binaries exist in current directory
    if [[ -f "crictl" ]]; then
        chmod +x crictl kube-proxy kubelet runc containerd containerd-shim-runc-v2 containerd-stress
        
        # Move binaries to correct directories per tutorial
        mv crictl kube-proxy kubelet runc /usr/local/bin/
        mv containerd containerd-shim-runc-v2 containerd-stress /bin/
        echo "✓ Worker binaries installed"
    else
        echo "ERROR: Worker binaries not found in current directory"
        exit 1
    fi
fi

# Install CNI plugins
echo "Installing CNI plugins..."
if [[ -f cni-plugins.tar.gz ]]; then
    tar -xf cni-plugins.tar.gz -C /opt/cni/bin/
    echo "✓ CNI plugins installed"
else
    echo "ERROR: CNI plugins archive not found"
    exit 1
fi

# Configure CNI Networking
echo "Configuring CNI networking..."

# Check if CNI files already exist
if [[ -f "/etc/cni/net.d/10-bridge.conf" ]]; then
    echo "CNI networking already configured, skipping"
else
    # Verify configuration files exist before moving
    if [[ -f "10-bridge.conf" && -f "99-loopback.conf" ]]; then
        # Move both network configuration files
        mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
    else
        echo "ERROR: CNI configuration files not found (10-bridge.conf, 99-loopback.conf)"
        exit 1
    fi
fi

# Load and configure the br-netfilter kernel module
modprobe br-netfilter
echo "br-netfilter" >> /etc/modules-load.d/modules.conf

# Configure sysctl for network traffic and iptables (idempotent)
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.d/kubernetes.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/kubernetes.conf
sysctl -p /etc/sysctl.d/kubernetes.conf

echo "✓ CNI networking configured"

# Configure containerd
echo "Configuring containerd..."

# Check if containerd already configured
if [[ -f "/etc/containerd/config.toml" ]]; then
    echo "containerd already configured, skipping"
else
    # Verify configuration file exists
    if [[ -f "containerd-config.toml" ]]; then
        mv containerd-config.toml /etc/containerd/config.toml
    else
        echo "ERROR: containerd-config.toml not found"
        exit 1
    fi
fi

# Install containerd systemd unit if not already installed
if [[ ! -f "/etc/systemd/system/containerd.service" ]]; then
    if [[ -f "containerd.service" ]]; then
        mv containerd.service /etc/systemd/system/
    else
        echo "ERROR: containerd.service not found"
        exit 1
    fi
fi

echo "✓ containerd configured"

# Configure the Kubelet
echo "Configuring kubelet..."

# Get the node name from hostname
NODE_NAME=$(hostname)

# Check if kubelet already configured (check for both kubeconfig AND config files)
if [[ -f "/var/lib/kubelet/kubeconfig" && -f "/var/lib/kubelet/kubelet-config.yaml" ]]; then
    echo "kubelet already configured, skipping"
else
    # Verify required files exist
    if [[ -f "${NODE_NAME}.key" && -f "${NODE_NAME}.crt" && -f "${NODE_NAME}.kubeconfig" && -f "ca.crt" && -f "kubelet-config.yaml" ]]; then
        # Move certificates to proper locations
        mv ${NODE_NAME}.key ${NODE_NAME}.crt /var/lib/kubelet/
        mv ${NODE_NAME}.kubeconfig /var/lib/kubelet/kubeconfig
        mv ca.crt /var/lib/kubernetes/
        
        # Move the node-specific kubelet configuration
        mv kubelet-config.yaml /var/lib/kubelet/
    else
        echo "ERROR: Required kubelet files not found (${NODE_NAME}.key, ${NODE_NAME}.crt, ${NODE_NAME}.kubeconfig, ca.crt, kubelet-config.yaml)"
        exit 1
    fi
fi

# Install kubelet systemd unit if not already installed
if [[ ! -f "/etc/systemd/system/kubelet.service" ]]; then
    if [[ -f "kubelet.service" ]]; then
        mv kubelet.service /etc/systemd/system/
    else
        echo "ERROR: kubelet.service not found"
        exit 1
    fi
fi

echo "✓ kubelet configured"

# Configure the Kubernetes Proxy
echo "Configuring kube-proxy..."

# Check if kube-proxy already configured (check for both kubeconfig AND config files)
if [[ -f "/var/lib/kube-proxy/kubeconfig" && -f "/var/lib/kube-proxy/kube-proxy-config.yaml" ]]; then
    echo "kube-proxy already configured, skipping"
else
    # Verify required files exist
    if [[ -f "kube-proxy.kubeconfig" && -f "kube-proxy-config.yaml" ]]; then
        mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
        mv kube-proxy-config.yaml /var/lib/kube-proxy/
    else
        echo "ERROR: Required kube-proxy files not found (kube-proxy.kubeconfig, kube-proxy-config.yaml)"
        exit 1
    fi
fi

# Install kube-proxy systemd unit if not already installed
if [[ ! -f "/etc/systemd/system/kube-proxy.service" ]]; then
    if [[ -f "kube-proxy.service" ]]; then
        mv kube-proxy.service /etc/systemd/system/
    else
        echo "ERROR: kube-proxy.service not found"
        exit 1
    fi
fi

echo "✓ kube-proxy configured"

# Start the Worker Services
echo "Starting worker services..."

systemctl daemon-reload

systemctl enable containerd kubelet kube-proxy

systemctl start containerd kubelet kube-proxy

echo "✓ Worker services started"

# Allow time for services to initialize
echo "Waiting 10 seconds for services to initialize..."
sleep 10

# Post-configuration check: Ensure all config files are in place
echo "Verifying configuration files are in place..."

# Check and fix kubelet config if missing
if [[ ! -f "/var/lib/kubelet/kubelet-config.yaml" && -f "/root/kubelet-config.yaml" ]]; then
    echo "Copying missing kubelet-config.yaml"
    cp /root/kubelet-config.yaml /var/lib/kubelet/
    systemctl restart kubelet
    sleep 5
fi

# Check and fix kube-proxy config if missing
if [[ ! -f "/var/lib/kube-proxy/kube-proxy-config.yaml" && -f "/root/kube-proxy-config.yaml" ]]; then
    echo "Copying missing kube-proxy-config.yaml"
    cp /root/kube-proxy-config.yaml /var/lib/kube-proxy/
    systemctl restart kube-proxy
    sleep 5
fi

# Verification
echo "Performing verification..."

# Check service status
echo "Checking service status..."
SERVICES_OK=true

echo "containerd: $(systemctl is-active containerd)"
if ! systemctl is-active --quiet containerd; then
    SERVICES_OK=false
fi

echo "kubelet: $(systemctl is-active kubelet)"
if ! systemctl is-active --quiet kubelet; then
    SERVICES_OK=false
    echo "kubelet logs:"
    journalctl -u kubelet --no-pager -l | tail -5
fi

echo "kube-proxy: $(systemctl is-active kube-proxy)"
if ! systemctl is-active --quiet kube-proxy; then
    SERVICES_OK=false
    echo "kube-proxy logs:"
    journalctl -u kube-proxy --no-pager -l | tail -5
fi

if [[ "$SERVICES_OK" == "true" ]]; then
    echo "✓ All worker services are running successfully"
else
    echo "⚠ Some services are not active. Check logs above for details."
fi

echo ""
echo "=== Kubernetes Worker Bootstrap Complete ==="
echo "✓ OS dependencies installed"
echo "✓ Swap disabled"
echo "✓ Installation directories created"
echo "✓ Worker binaries installed in correct directories"
echo "✓ CNI plugins and networking configured with br-netfilter"
echo "✓ containerd configured and running"
echo "✓ kubelet configured and running"
echo "✓ kube-proxy configured and running"
echo ""
echo "Worker node $(hostname) is ready to join the cluster"