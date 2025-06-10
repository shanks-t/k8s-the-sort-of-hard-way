#!/bin/bash

# Quick fix script to set up SSH connectivity from jumpbox to cluster nodes
# Run this on the jumpbox as root

echo "Setting up SSH connectivity from jumpbox to cluster nodes..."

# Generate SSH key pair for cluster communication (if not exists)
if [[ ! -f "/root/.ssh/cluster_rsa" ]]; then
    echo "Generating SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/cluster_rsa -N "" -C "jumpbox-cluster-key"
    chmod 600 /root/.ssh/cluster_rsa
    chmod 644 /root/.ssh/cluster_rsa.pub
    echo "SSH key pair generated successfully"
else
    echo "SSH key pair already exists"
fi

# Set up SSH config for easy access to cluster nodes
echo "Setting up SSH config..."
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
    echo "Setting up SSH config for trey user..."
    mkdir -p /home/trey/.ssh
    cp /root/.ssh/config /home/trey/.ssh/config
    cp /root/.ssh/cluster_rsa /home/trey/.ssh/cluster_rsa
    cp /root/.ssh/cluster_rsa.pub /home/trey/.ssh/cluster_rsa.pub
    chown -R trey:trey /home/trey/.ssh
    chmod 600 /home/trey/.ssh/config
    chmod 600 /home/trey/.ssh/cluster_rsa
    chmod 644 /home/trey/.ssh/cluster_rsa.pub
fi

# Read machines.txt and distribute SSH key to each node
echo "Distributing SSH key to cluster nodes..."
while read IP FQDN HOST SUBNET; do
    echo "Setting up SSH access to $HOST ($IP)..."
    
    # Copy jumpbox SSH public key to remote host
    if scp -o StrictHostKeyChecking=no -o ConnectTimeout=30 /root/.ssh/cluster_rsa.pub root@${IP}:~/jumpbox_key.pub 2>/dev/null; then
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 root@${IP} "cat jumpbox_key.pub >> /root/.ssh/authorized_keys && rm jumpbox_key.pub" 2>/dev/null; then
            echo "✓ Successfully added jumpbox SSH key to root@$HOST"
        else
            echo "✗ Failed to add jumpbox SSH key to root@$HOST"
        fi
    else
        echo "✗ Failed to copy jumpbox SSH key to $HOST"
    fi
    
    # Also add to trey user if exists
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 root@${IP} "test -d /home/trey" 2>/dev/null; then
        if scp -o StrictHostKeyChecking=no -o ConnectTimeout=30 /root/.ssh/cluster_rsa.pub root@${IP}:~/jumpbox_key_trey.pub 2>/dev/null; then
            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 root@${IP} "cat jumpbox_key_trey.pub >> /home/trey/.ssh/authorized_keys && rm jumpbox_key_trey.pub" 2>/dev/null; then
                echo "✓ Successfully added jumpbox SSH key to trey@$HOST"
            else
                echo "✗ Failed to add jumpbox SSH key to trey@$HOST"
            fi
        fi
    fi
done < /root/machines.txt

echo ""
echo "SSH setup completed! You can now SSH to cluster nodes using:"
echo "  ssh server    (or ssh controller)"
echo "  ssh node-0    (or ssh worker-0)" 
echo "  ssh node-1    (or ssh worker-1)"
echo ""
echo "Test connectivity:"
echo "  ssh server hostname"
echo "  ssh node-0 hostname"
echo "  ssh node-1 hostname"