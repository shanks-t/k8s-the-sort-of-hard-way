#!/bin/bash

# Kubernetes The Hard Way - etcd Cluster Bootstrapping
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/07-bootstrapping-etcd.md

set -e

echo "Starting etcd cluster bootstrapping..."

# Check prerequisites - ensure we're running on the controller node
if [[ "$(hostname)" != "controller" ]]; then
    echo "ERROR: This script must be run on the controller node"
    echo "Current hostname: $(hostname)"
    exit 1
fi

cd /root

echo "Verifying required files exist..."

# Check for required binaries (should be copied from jumpbox)
required_binaries=(
    "etcd"
    "etcdctl"
)

for binary in "${required_binaries[@]}"; do
    if [[ ! -f "$binary" ]]; then
        echo "ERROR: Required binary not found: /root/$binary"
        echo "Please ensure binaries have been copied from jumpbox first"
        exit 1
    fi
    echo "✓ Found: /root/$binary"
done

# Check for required certificates (should be copied from previous ca-tls script)
required_certs=(
    "ca.crt"
    "kube-api-server.key" 
    "kube-api-server.crt"
)

for cert in "${required_certs[@]}"; do
    if [[ ! -f "$cert" ]]; then
        echo "ERROR: Required certificate not found: /root/$cert"
        echo "Please ensure certificates have been copied from jumpbox first"
        exit 1
    fi
    echo "✓ Found: /root/$cert"
done

echo "All prerequisites verified successfully!"

# Install etcd binaries
echo "Installing etcd binaries..."
cp etcd /usr/local/bin/
cp etcdctl /usr/local/bin/
chmod +x /usr/local/bin/etcd /usr/local/bin/etcdctl

echo "Verifying etcd installation..."
if ! /usr/local/bin/etcd --version > /dev/null 2>&1; then
    echo "ERROR: etcd installation failed"
    exit 1
fi

if ! /usr/local/bin/etcdctl version > /dev/null 2>&1; then
    echo "ERROR: etcdctl installation failed" 
    exit 1
fi

echo "✓ etcd binaries installed successfully"

# Create etcd directories
echo "Creating etcd directories..."
mkdir -p /etc/etcd /var/lib/etcd
chmod 700 /var/lib/etcd
echo "✓ etcd directories created"

# Copy SSL certificates
echo "Copying SSL certificates to etcd directory..."
cp ca.crt kube-api-server.key kube-api-server.crt /etc/etcd/
echo "✓ SSL certificates copied to /etc/etcd/"

# Create etcd systemd unit file
echo "Creating etcd systemd unit file..."
cat > /etc/systemd/system/etcd.service << 'EOF'
[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name controller \
  --initial-advertise-peer-urls http://127.0.0.1:2380 \
  --listen-peer-urls http://127.0.0.1:2380 \
  --listen-client-urls http://127.0.0.1:2379 \
  --advertise-client-urls http://127.0.0.1:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster controller=http://127.0.0.1:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "✓ etcd systemd unit file created"

# Start etcd service
echo "Starting etcd service..."
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd

# Wait for etcd to be ready
echo "Waiting for etcd to be ready..."
sleep 5

# Verify etcd is running
if ! systemctl is-active --quiet etcd; then
    echo "ERROR: etcd service failed to start"
    echo "Service status:"
    systemctl status etcd
    echo "Logs:"
    journalctl -u etcd --no-pager -l
    exit 1
fi

echo "✓ etcd service started successfully"

# Verify etcd cluster
echo "Verifying etcd cluster..."
if etcdctl member list > /dev/null 2>&1; then
    echo "✓ etcd cluster verification successful"
    echo "Cluster members:"
    etcdctl member list
else
    echo "ERROR: etcd cluster verification failed"
    echo "etcdctl output:"
    etcdctl member list || true
    echo "Service status:"
    systemctl status etcd
    exit 1
fi

echo ""
echo "=== etcd Bootstrapping Complete ==="
echo "✓ etcd binaries installed in /usr/local/bin/"
echo "✓ etcd directories created (/etc/etcd, /var/lib/etcd)"
echo "✓ SSL certificates configured"
echo "✓ systemd service created and started"
echo "✓ etcd cluster verified and running"
echo ""
echo "etcd cluster details:"
etcdctl member list
echo ""
echo "Next step: Bootstrap Kubernetes Controllers (Lab 08)"