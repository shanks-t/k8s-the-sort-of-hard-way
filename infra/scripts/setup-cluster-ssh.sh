#!/bin/bash

# SSH key setup script for Kubernetes The Hard Way cluster
# This script sets up passwordless SSH between jumpbox and cluster nodes

set -e

LOGFILE="/var/log/cluster-ssh-setup.log"
ERRORLOG="/var/log/cluster-ssh-setup-error.log"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# Function to log errors
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$ERRORLOG" >&2
}

log "Starting cluster SSH key setup..."

# Generate SSH key pair for cluster communication (if not exists)
if [[ ! -f "/root/.ssh/cluster_rsa" ]]; then
    log "Generating SSH key pair for cluster communication..."
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/cluster_rsa -N "" -C "jumpbox-cluster-key"
    chmod 600 /root/.ssh/cluster_rsa
    chmod 644 /root/.ssh/cluster_rsa.pub
    log "SSH key pair generated successfully"
else
    log "SSH key pair already exists"
fi

# Add the public key to authorized_keys for all users
log "Adding cluster SSH key to authorized_keys..."
cat /root/.ssh/cluster_rsa.pub >> /root/.ssh/authorized_keys
if [[ -f "/home/trey/.ssh/authorized_keys" ]]; then
    cat /root/.ssh/cluster_rsa.pub >> /home/trey/.ssh/authorized_keys
fi

# Set up SSH config for easy access to cluster nodes
log "Setting up SSH config..."
cat > /root/.ssh/config << 'EOF'
Host server controller
    HostName 10.240.0.10
    User root
    IdentityFile /root/.ssh/cluster_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host node-0 worker-0
    HostName 10.240.0.20
    User root
    IdentityFile /root/.ssh/cluster_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host node-1 worker-1
    HostName 10.240.0.21
    User root
    IdentityFile /root/.ssh/cluster_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

chmod 600 /root/.ssh/config

# Also set up for trey user
if [[ -d "/home/trey" ]]; then
    log "Setting up SSH config for trey user..."
    mkdir -p /home/trey/.ssh
    cp /root/.ssh/config /home/trey/.ssh/config
    cp /root/.ssh/cluster_rsa /home/trey/.ssh/cluster_rsa
    cp /root/.ssh/cluster_rsa.pub /home/trey/.ssh/cluster_rsa.pub
    chown -R trey:trey /home/trey/.ssh
    chmod 600 /home/trey/.ssh/config
    chmod 600 /home/trey/.ssh/cluster_rsa
    chmod 644 /home/trey/.ssh/cluster_rsa.pub
fi

log "Cluster SSH setup completed successfully!"
log "You can now SSH to cluster nodes using:"
log "  ssh server    (or ssh controller)"
log "  ssh node-0    (or ssh worker-0)" 
log "  ssh node-1    (or ssh worker-1)"