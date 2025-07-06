#!/bin/bash

# Worker-specific setup script template
# Sets hostname and prepares for Kubernetes worker node

# Setup logging
LOGFILE="/var/log/worker-setup.log"
ERRORLOG="/var/log/worker-setup-error.log"

# Create log files
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
trap 'log_error "Worker setup failed at line $LINENO with exit code $?"' ERR

WORKER_INDEX="${worker_index}"

log "Starting worker-$WORKER_INDEX specific setup..."

# Set hostname for worker node (must match certificate name)
log "Setting hostname to node-$WORKER_INDEX..."
hostnamectl set-hostname "node-$WORKER_INDEX" || { log_error "Failed to set hostname"; exit 1; }
sed -i '/^127.0.1.1/d' /etc/hosts
echo "127.0.1.1 node-$WORKER_INDEX node-$WORKER_INDEX.kubernetes.local worker-$WORKER_INDEX" >> /etc/hosts

# Restart hostname service
log "Restarting hostname service..."
systemctl restart systemd-hostnamed || { log_error "Failed to restart systemd-hostnamed"; exit 1; }

# Enable IP forwarding for Kubernetes
log "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Load required kernel modules for container runtime
log "Loading required kernel modules..."
modprobe overlay
modprobe br_netfilter

# Make modules persistent
cat << EOF >> /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Extract bootstrap workers script from Google Cloud metadata
log "Installing bootstrap workers script..."
if curl -f -H "Metadata-Flavor: Google" \
   "http://metadata.google.internal/computeMetadata/v1/instance/attributes/bootstrap-workers-script" \
   -o /root/bootstrap-workers.sh 2>/dev/null; then
    chmod +x /root/bootstrap-workers.sh
    log "Bootstrap workers script installed at /root/bootstrap-workers.sh"
else
    log_error "Failed to retrieve bootstrap workers script from metadata"
fi

# Validate script was installed
log "Validating installed script..."
if [[ -f "/root/bootstrap-workers.sh" && -x "/root/bootstrap-workers.sh" ]]; then
    log "✓ Script validated: /root/bootstrap-workers.sh"
else
    log_error "✗ Script missing or not executable: /root/bootstrap-workers.sh"
fi

log "Worker-$WORKER_INDEX setup completed successfully!"
log "Setup logs available at: $LOGFILE"
log "Error logs available at: $ERRORLOG"