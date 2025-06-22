#!/bin/bash

# Jumpbox-specific setup script following Kubernetes The Hard Way tutorial
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-jumpbox.md

# Setup logging
LOGFILE="/var/log/jumpbox-setup.log"
ERRORLOG="/var/log/jumpbox-setup-error.log"

# Create log directory and files
mkdir -p /var/log
touch "$LOGFILE" "$ERRORLOG"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# Function to log errors
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$ERRORLOG" >&2
}

# Redirect all output to logs
exec > >(tee -a "$LOGFILE")
exec 2> >(tee -a "$ERRORLOG" >&2)

# Error handling
set -e
trap 'log_error "Script failed at line $LINENO with exit code $?"' ERR

log "Starting Kubernetes The Hard Way jumpbox setup..."

# Debug information
log "Debug Info:"
log "- User: $(whoami)"
log "- UID: $(id -u)"
log "- Working Directory: $(pwd)"
log "- Architecture: $(dpkg --print-architecture)"
log "- OS: $(cat /etc/os-release | grep PRETTY_NAME)"

# Verify running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (current UID: $EUID)"
    exit 1
fi

log "Verified running as root"

# Set hostname for jumpbox
log "Setting hostname to jumpbox..."
hostnamectl set-hostname jumpbox || { log_error "Failed to set hostname"; exit 1; }
sed -i '/^127.0.1.1/d' /etc/hosts
echo "127.0.1.1 jumpbox jumpbox.kubernetes.local" >> /etc/hosts

# Restart hostname service
log "Restarting hostname service..."
systemctl restart systemd-hostnamed || { log_error "Failed to restart systemd-hostnamed"; exit 1; }

# Configure root SSH access
log "Configuring root SSH access..."
# Copy SSH key from the regular user to root
if [[ -f "/home/trey/.ssh/authorized_keys" ]]; then
    mkdir -p /root/.ssh
    cp /home/trey/.ssh/authorized_keys /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
    chown -R root:root /root/.ssh
    log "SSH key copied to root user"
else
    log_error "SSH key not found for user trey"
fi

# Install command line utilities (as per tutorial)
log "Installing command line utilities..."
export DEBIAN_FRONTEND=noninteractive
apt-get update || { log_error "apt-get update failed"; exit 1; }
apt-get -y install wget curl vim openssl git || { log_error "Failed to install packages"; exit 1; }

# Create machines.txt file for cluster management
log "Creating machines.txt file..."
cat > /root/machines.txt << 'EOF'
10.240.0.10 server.kubernetes.local server
10.240.0.20 node-0.kubernetes.local node-0 10.200.0.0/24
10.240.0.21 node-1.kubernetes.local node-1 10.200.1.0/24
EOF

log "machines.txt created with $(wc -l < /root/machines.txt) entries"

# Generate hosts file for cluster nodes
log "Generating hosts file for cluster nodes..."
cd /root
echo "" > hosts
echo "# Kubernetes The Hard Way" >> hosts

while read IP FQDN HOST SUBNET; do
    ENTRY="${IP} ${FQDN} ${HOST}"
    echo $ENTRY >> hosts
    log "Added host entry: $ENTRY"
done < machines.txt

# Update local /etc/hosts with cluster nodes
log "Updating /etc/hosts with cluster nodes..."
cat hosts >> /etc/hosts

# Clone Kubernetes The Hard Way repository
log "Cloning Kubernetes The Hard Way repository..."
cd /root
if ! git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git; then
    log_error "Failed to clone repository"
    exit 1
fi

cd kubernetes-the-hard-way
log "Repository cloned successfully, current directory: $(pwd)"

# Download Kubernetes binaries
log "Downloading Kubernetes binaries..."
ARCH=$(dpkg --print-architecture)
log "Architecture detected: $ARCH"

if [[ ! -f "downloads-${ARCH}.txt" ]]; then
    log_error "Download file downloads-${ARCH}.txt not found"
    exit 1
fi

log "Download list contains $(wc -l < downloads-${ARCH}.txt) files"

if ! wget -q --https-only --timestamping -P downloads -i downloads-${ARCH}.txt; then
    log_error "Failed to download binaries"
    exit 1
fi

log "Downloaded files:"
ls -la downloads/ | tee -a "$LOGFILE"

# Extract and organize binaries
log "Extracting and organizing binaries..."
{
    mkdir -p downloads/{client,cni-plugins,controller,worker}
    
    # Extract crictl
    log "Extracting crictl..."
    if [[ -f "downloads/crictl-v1.32.0-linux-${ARCH}.tar.gz" ]]; then
        tar -xf downloads/crictl-v1.32.0-linux-${ARCH}.tar.gz -C downloads/worker/
    else
        log_error "crictl tar file not found"
        exit 1
    fi
    
    # Extract containerd
    log "Extracting containerd..."
    if [[ -f "downloads/containerd-2.1.0-beta.0-linux-${ARCH}.tar.gz" ]]; then
        tar -xf downloads/containerd-2.1.0-beta.0-linux-${ARCH}.tar.gz --strip-components 1 -C downloads/worker/
    else
        log_error "containerd tar file not found"
        exit 1
    fi
    
    # Extract CNI plugins
    log "Extracting CNI plugins..."
    if [[ -f "downloads/cni-plugins-linux-${ARCH}-v1.6.2.tgz" ]]; then
        tar -xf downloads/cni-plugins-linux-${ARCH}-v1.6.2.tgz -C downloads/cni-plugins/
    else
        log_error "CNI plugins tar file not found"
        exit 1
    fi
    
    # Extract etcd
    log "Extracting etcd..."
    if [[ -f "downloads/etcd-v3.6.0-rc.3-linux-${ARCH}.tar.gz" ]]; then
        tar -xf downloads/etcd-v3.6.0-rc.3-linux-${ARCH}.tar.gz \
            -C downloads/ \
            --strip-components 1 \
            etcd-v3.6.0-rc.3-linux-${ARCH}/etcdctl \
            etcd-v3.6.0-rc.3-linux-${ARCH}/etcd
    else
        log_error "etcd tar file not found"
        exit 1
    fi
    
    # Move binaries to appropriate directories
    log "Moving binaries to appropriate directories..."
    mv downloads/{etcdctl,kubectl} downloads/client/
    mv downloads/{etcd,kube-apiserver,kube-controller-manager,kube-scheduler} downloads/controller/
    mv downloads/{kubelet,kube-proxy} downloads/worker/
    mv downloads/runc.${ARCH} downloads/worker/runc
}

log "Binary organization completed. Directory contents:"
log "Client tools: $(ls downloads/client/)"
log "Controller binaries: $(ls downloads/controller/)"
log "Worker binaries: $(ls downloads/worker/)"
log "CNI plugins: $(ls downloads/cni-plugins/ | wc -l) plugins"

# Install kubectl
log "Installing kubectl..."
if [[ -f "downloads/client/kubectl" ]]; then
    cp downloads/client/kubectl /usr/local/bin/
    chmod +x /usr/local/bin/kubectl
else
    log_error "kubectl binary not found"
    exit 1
fi

# Verify kubectl installation
log "Verifying kubectl installation..."
if kubectl version --client; then
    log "kubectl installed successfully"
else
    log_error "kubectl verification failed"
    exit 1
fi

# Save CA/TLS certificate generation script
log "Installing CA/TLS certificate generation script..."
if curl -f -H "Metadata-Flavor: Google" \
   "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ca-tls-script" \
   -o /root/ca-tls.sh 2>/dev/null; then
    chmod +x /root/ca-tls.sh
    log "CA/TLS script installed at /root/ca-tls.sh"
else
    log_error "Failed to retrieve CA/TLS script from metadata"
fi

# Save kubeconfig setup script
log "Installing kubeconfig setup script..."
if curl -f -H "Metadata-Flavor: Google" \
   "http://metadata.google.internal/computeMetadata/v1/instance/attributes/kubeconfig-setup-script" \
   -o /root/kubeconfig-setup.sh 2>/dev/null; then
    chmod +x /root/kubeconfig-setup.sh
    log "Kubeconfig setup script installed at /root/kubeconfig-setup.sh"
else
    log_error "Failed to retrieve kubeconfig setup script from metadata"
fi

# Save encryption setup script
log "Installing encryption setup script..."
if curl -f -H "Metadata-Flavor: Google" \
   "http://metadata.google.internal/computeMetadata/v1/instance/attributes/encryption-setup-script" \
   -o /root/encryption-setup.sh 2>/dev/null; then
    chmod +x /root/encryption-setup.sh
    log "Encryption setup script installed at /root/encryption-setup.sh"
else
    log_error "Failed to retrieve encryption setup script from metadata"
fi

# Validate all scripts were installed
log "Validating installed scripts..."
scripts_to_check=("/root/ca-tls.sh" "/root/kubeconfig-setup.sh" "/root/encryption-setup.sh")
for script in "${scripts_to_check[@]}"; do
    if [[ -f "$script" && -x "$script" ]]; then
        log "✓ Script validated: $script"
    else
        log_error "✗ Script missing or not executable: $script"
    fi
done

log "Jumpbox setup completed successfully!"
log "Setup logs available at: $LOGFILE"
log "Error logs available at: $ERRORLOG"