#!/bin/bash

# Kubernetes The Hard Way - Worker Binaries Distribution
# This script copies all worker node binaries and configs to both worker nodes
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md

set -e

echo "Starting Kubernetes worker binaries and config distribution..."

# Verify we're in the correct directory
if [[ ! -d "/root/kubernetes-the-hard-way" ]]; then
    echo "ERROR: kubernetes-the-hard-way directory not found"
    exit 1
fi

cd /root/kubernetes-the-hard-way

# Verify machines.txt exists
if [[ ! -f "/root/machines.txt" ]]; then
    echo "ERROR: machines.txt not found"
    exit 1
fi

# Verify required worker binaries exist
echo "Verifying worker binaries..."
required_worker_binaries=(
    "downloads/worker/crictl"
    "downloads/worker/kube-proxy"
    "downloads/worker/kubelet"
    "downloads/worker/runc"
    "downloads/worker/containerd"
    "downloads/worker/containerd-shim-runc-v2"
    "downloads/worker/containerd-stress"
)

for binary in "${required_worker_binaries[@]}"; do
    if [[ ! -f "$binary" ]]; then
        echo "ERROR: Required worker binary not found: $binary"
        exit 1
    fi
    echo "✓ Found: $binary"
done

# Verify required client binaries exist
echo "Verifying client binaries..."
if [[ ! -f "downloads/client/kubectl" ]]; then
    echo "ERROR: kubectl not found"
    exit 1
fi
echo "✓ Found: downloads/client/kubectl"

# Verify CNI plugins exist
echo "Verifying CNI plugins..."
if [[ ! -d "downloads/cni-plugins" ]] || [[ -z "$(ls -A downloads/cni-plugins/)" ]]; then
    echo "ERROR: CNI plugins directory not found or empty"
    exit 1
fi
echo "✓ Found CNI plugins: $(ls downloads/cni-plugins/ | wc -l) plugins"

# Verify required config files exist
echo "Verifying configuration files..."
required_configs=(
    "configs/10-bridge.conf"
    "configs/99-loopback.conf"
    "configs/kubelet-config.yaml"
    "configs/kube-proxy-config.yaml"
    "configs/containerd-config.toml"
)

for config in "${required_configs[@]}"; do
    if [[ ! -f "$config" ]]; then
        echo "ERROR: Required config file not found: $config"
        exit 1
    fi
    echo "✓ Found: $config"
done

# Verify required service files exist
echo "Verifying systemd service files..."
required_services=(
    "units/containerd.service"
    "units/kubelet.service"
    "units/kube-proxy.service"
)

for service in "${required_services[@]}"; do
    if [[ ! -f "$service" ]]; then
        echo "ERROR: Required service file not found: $service"
        exit 1
    fi
    echo "✓ Found: $service"
done

echo "All required files verified!"

# Set execute permissions on all binaries before copying
echo "Setting execute permissions on binaries..."
chmod +x downloads/worker/* downloads/client/kubectl downloads/cni-plugins/*

# Process each worker node
for HOST in node-0 node-1; do
    echo ""
    echo "=== Processing worker node: $HOST ==="
    
    # Get subnet for this worker from machines.txt
    SUBNET=$(grep ${HOST} /root/machines.txt | cut -d " " -f 4)
    if [[ -z "$SUBNET" ]]; then
        echo "ERROR: Could not find subnet for $HOST in machines.txt"
        exit 1
    fi
    echo "Using subnet $SUBNET for $HOST"
    
    # Create worker-specific CNI bridge config
    echo "Creating worker-specific CNI bridge config for $HOST..."
    sed "s|SUBNET|$SUBNET|g" configs/10-bridge.conf > /tmp/10-bridge-${HOST}.conf
    
    # Create worker-specific kubelet config
    echo "Creating worker-specific kubelet config for $HOST..."
    sed "s|SUBNET|$SUBNET|g" configs/kubelet-config.yaml > /tmp/kubelet-config-${HOST}.yaml
    
    # Create CNI plugins directory on worker
    echo "Creating CNI plugins directory on $HOST..."
    ssh root@${HOST} "mkdir -p ~/cni-plugins"
    
    # Copy worker-specific configs
    echo "Copying worker-specific configs to $HOST..."
    scp /tmp/10-bridge-${HOST}.conf root@${HOST}:~/10-bridge.conf
    scp /tmp/kubelet-config-${HOST}.yaml root@${HOST}:~/kubelet-config.yaml
    
    # Copy all worker binaries and general configs
    echo "Copying worker binaries and configs to $HOST..."
    scp downloads/worker/* downloads/client/kubectl root@${HOST}:~/
    scp configs/99-loopback.conf configs/kube-proxy-config.yaml configs/containerd-config.toml root@${HOST}:~/
    scp units/containerd.service units/kubelet.service units/kube-proxy.service root@${HOST}:~/
    
    # Copy CNI plugins
    echo "Copying CNI plugins to $HOST..."
    scp downloads/cni-plugins/* root@${HOST}:~/cni-plugins/
    
    # Verify files were copied successfully
    echo "Verifying files on $HOST..."
    ssh root@${HOST} 'ls -la ~/ | grep -E "(crictl|kube-proxy|kubelet|runc|containerd|kubectl)"'
    ssh root@${HOST} 'ls -la ~/cni-plugins/ | wc -l'
    
    # Clean up temporary files
    rm -f /tmp/10-bridge-${HOST}.conf /tmp/kubelet-config-${HOST}.yaml
    
    echo "✓ $HOST setup complete"
done

echo ""
echo "=== Worker Binaries Distribution Complete ==="
echo "✓ Worker binaries copied to both nodes"
echo "✓ CNI plugins distributed"
echo "✓ Configuration files customized per node"
echo "✓ systemd service files copied"
echo ""
echo "Next step: Run worker-node-setup.sh on each worker node"