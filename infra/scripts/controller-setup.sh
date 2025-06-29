#!/bin/bash

# Kubernetes The Hard Way - Controller Node Setup
# This script sets up the controller node and retrieves bootstrap scripts

# Setup logging
LOGFILE="/var/log/controller-setup.log"
ERRORLOG="/var/log/controller-setup-error.log"

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
trap 'log_error "Controller setup failed at line $LINENO with exit code $?"' ERR

log "Starting controller node setup..."

# Set hostname for controller
log "Setting hostname to controller..."
hostnamectl set-hostname controller || { log_error "Failed to set hostname"; exit 1; }
sed -i '/^127.0.1.1/d' /etc/hosts
echo "127.0.1.1 controller controller.kubernetes.local server.kubernetes.local server" >> /etc/hosts

# Restart hostname service
log "Restarting hostname service..."
systemctl restart systemd-hostnamed || { log_error "Failed to restart systemd-hostnamed"; exit 1; }

# Enable IP forwarding
log "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-kubernetes.conf
sysctl --system

# Save etcd setup script
log "Installing etcd setup script..."
if curl -f -H "Metadata-Flavor: Google" \
   "http://metadata.google.internal/computeMetadata/v1/instance/attributes/etcd-setup-script" \
   -o /root/etcd-setup.sh 2>/dev/null; then
    chmod +x /root/etcd-setup.sh
    log "etcd setup script installed at /root/etcd-setup.sh"
else
    log_error "Failed to retrieve etcd setup script from metadata"
fi

# Save bootstrap controllers script
log "Installing bootstrap controllers script..."
if curl -f -H "Metadata-Flavor: Google" \
   "http://metadata.google.internal/computeMetadata/v1/instance/attributes/bootstrap-controllers-script" \
   -o /root/bootstrap-controllers.sh 2>/dev/null; then
    chmod +x /root/bootstrap-controllers.sh
    log "Bootstrap controllers script installed at /root/bootstrap-controllers.sh"
else
    log_error "Failed to retrieve bootstrap controllers script from metadata"
fi

# Validate scripts were installed
log "Validating installed scripts..."
scripts_to_check=("/root/etcd-setup.sh" "/root/bootstrap-controllers.sh")
for script in "${scripts_to_check[@]}"; do
    if [[ -f "$script" && -x "$script" ]]; then
        log "✓ Script validated: $script"
    else
        log_error "✗ Script missing or not executable: $script"
    fi
done

log "Controller setup completed successfully!"
log "Setup logs available at: $LOGFILE"
log "Error logs available at: $ERRORLOG"