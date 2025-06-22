#!/bin/bash

# Kubernetes The Hard Way - RBAC Configuration
# This script configures RBAC permissions for the kubelet API
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md

set -e

echo "Starting RBAC configuration..."

# Verify required files exist
if [[ ! -f "admin.kubeconfig" ]]; then
    echo "ERROR: admin.kubeconfig not found"
    exit 1
fi

if [[ ! -f "kube-apiserver-to-kubelet.yaml" ]]; then
    echo "ERROR: kube-apiserver-to-kubelet.yaml not found"
    exit 1
fi

# Ensure kubectl is executable
if [[ ! -x "/usr/local/bin/kubectl" ]]; then
    echo "Setting execute permissions on kubectl..."
    chmod +x /usr/local/bin/kubectl
fi

# Wait for API server to be fully ready
echo "Waiting for API server to be ready..."
max_attempts=15
attempt=1

# First check if API server service is running
if ! systemctl is-active --quiet kube-apiserver; then
    echo "ERROR: kube-apiserver service is not running"
    systemctl status kube-apiserver --no-pager
    exit 1
fi

# Test API server health endpoint first (faster than kubectl)
while [ $attempt -le $max_attempts ]; do
    if curl -k -s https://127.0.0.1:6443/healthz | grep -q "ok"; then
        echo "✓ API server health endpoint responding"
        break
    else
        echo "Attempt $attempt/$max_attempts: API server health endpoint not ready, waiting..."
        sleep 5
        attempt=$((attempt + 1))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo "ERROR: API server health endpoint did not become ready within expected time"
    exit 1
fi

# Now test kubectl access
echo "Testing kubectl access to API server..."
attempt=1
while [ $attempt -le 10 ]; do
    if kubectl get componentstatuses --kubeconfig admin.kubeconfig &> /dev/null; then
        echo "✓ kubectl can access API server"
        break
    else
        echo "Attempt $attempt/10: kubectl access not ready yet, waiting..."
        sleep 5
        attempt=$((attempt + 1))
    fi
done

if [ $attempt -gt 10 ]; then
    echo "ERROR: kubectl could not access API server within expected time"
    exit 1
fi

# Apply RBAC configuration
echo "Applying RBAC configuration for kubelet API access..."
kubectl apply -f kube-apiserver-to-kubelet.yaml --kubeconfig admin.kubeconfig

# Verify RBAC configuration
echo "Verifying RBAC configuration..."
kubectl get clusterrole system:kube-apiserver-to-kubelet --kubeconfig admin.kubeconfig
kubectl get clusterrolebinding system:kube-apiserver --kubeconfig admin.kubeconfig

# Check component statuses
echo "Checking Kubernetes component statuses..."
kubectl get componentstatuses --kubeconfig admin.kubeconfig

# Validate API server version endpoint
echo ""
echo "Validating API server version endpoint..."
if curl -k https://127.0.0.1:6443/version &> /dev/null; then
    echo "✓ API server version endpoint accessible locally"
    curl -k https://127.0.0.1:6443/version 2>/dev/null | python3 -m json.tool || echo "API server version response received"
else
    echo "WARNING: API server version endpoint not accessible locally"
fi

# Test external endpoint if hostname resolution works
echo ""
echo "Testing external API server endpoint..."
if curl -k https://server.kubernetes.local:6443/version &> /dev/null; then
    echo "✓ API server accessible via external hostname"
    echo "API server version:"
    curl -k https://server.kubernetes.local:6443/version 2>/dev/null | python3 -m json.tool || echo "API server version response received"
else
    echo "NOTE: External hostname test failed (this may be expected depending on network configuration)"
fi

echo ""
echo "=== RBAC Configuration Complete ==="
echo "✓ ClusterRole system:kube-apiserver-to-kubelet created"
echo "✓ ClusterRoleBinding system:kube-apiserver created"
echo "✓ Kubernetes API server can now access kubelet API"
echo "✓ API server endpoints validated"
echo ""
echo "Control plane setup is now complete!"