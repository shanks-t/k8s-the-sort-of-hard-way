#!/bin/bash

# Common setup script for all Kubernetes The Hard Way instances
# This script configures SSH access, hostname resolution, and basic system setup

# Setup logging
HOSTNAME=$(hostname)
LOGFILE="/var/log/common-setup.log"
ERRORLOG="/var/log/common-setup-error.log"

# Create log directory and files
mkdir -p /var/log
touch "$LOGFILE" "$ERRORLOG"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$HOSTNAME] $1" | tee -a "$LOGFILE"
}

# Function to log errors
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$HOSTNAME] ERROR: $1" | tee -a "$ERRORLOG" >&2
}

# Redirect all output to logs
exec > >(tee -a "$LOGFILE")
exec 2> >(tee -a "$ERRORLOG" >&2)

# Error handling
set -e
trap 'log_error "Common setup failed at line $LINENO with exit code $?"' ERR

log "Starting common setup..."

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Debug information
log "Debug Info:"
log "- User: $(whoami)"
log "- UID: $(id -u)"
log "- Working Directory: $(pwd)"
log "- OS: $(cat /etc/os-release | grep PRETTY_NAME || echo 'Unknown')"

# Wait for SSH keys to be injected by GCP metadata agent
log "Waiting 30 seconds for GCP metadata agent to inject SSH keys..."
sleep 30

# Enable root SSH access for Kubernetes The Hard Way tutorial
log "Configuring SSH for root access..."
if sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config; then
    log "Root SSH access enabled"
else
    log_error "Failed to enable root SSH access"
    exit 1
fi

# Ensure SSH agent forwarding is allowed
log "Enabling SSH agent forwarding..."
if sed -i 's/^#*AllowAgentForwarding.*/AllowAgentForwarding yes/' /etc/ssh/sshd_config; then
    log "SSH agent forwarding enabled"
else
    log_error "Failed to enable SSH agent forwarding"
    exit 1
fi

# Configure root SSH access
log "Configuring root SSH access..."
# Copy SSH key from the regular user to root (if not already present)
if [[ -f "/home/trey/.ssh/authorized_keys" && ! -f "/root/.ssh/authorized_keys" ]]; then
    mkdir -p /root/.ssh
    cp /home/trey/.ssh/authorized_keys /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
    chown -R root:root /root/.ssh
    log "SSH key copied to root user"
elif [[ -f "/root/.ssh/authorized_keys" ]]; then
    log "Root SSH key already configured"
else
    log_error "SSH key not found for user trey"
fi

# Restart SSH daemon to apply configuration
log "Restarting SSH daemon..."
if systemctl restart sshd; then
    log "SSH daemon restarted successfully"
else
    log_error "Failed to restart SSH daemon"
    exit 1
fi

# Create hosts file entries for Kubernetes cluster
log "Adding Kubernetes cluster hosts to /etc/hosts..."
cat << 'HOSTS_EOF' >> /etc/hosts

# Kubernetes The Hard Way cluster hosts
10.240.0.9   jumpbox.kubernetes.local jumpbox
10.240.0.10  server.kubernetes.local server controller
10.240.0.20  node-0.kubernetes.local node-0 worker-0
10.240.0.21  node-1.kubernetes.local node-1 worker-1
HOSTS_EOF

log "Cluster hosts added to /etc/hosts"
log "Common setup completed successfully!"
log "Setup logs available at: $LOGFILE"
log "Error logs available at: $ERRORLOG"