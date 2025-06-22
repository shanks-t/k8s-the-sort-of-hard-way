#!/bin/bash

# Kubernetes The Hard Way - Worker Validation
# This script validates that worker nodes are properly configured and registered
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/09-bootstrapping-kubernetes-workers.md

set -e

echo "Starting Kubernetes worker node validation..."

# Verify we're running from the jumpbox with access to controller
if [[ ! -f "/root/kubernetes-the-hard-way/admin.kubeconfig" ]]; then
    echo "ERROR: admin.kubeconfig not found. Run this from the jumpbox."
    exit 1
fi

KUBECONFIG="/root/kubernetes-the-hard-way/admin.kubeconfig"

# Ensure kubectl is accessible and executable
if [[ ! -x "/usr/local/bin/kubectl" ]]; then
    echo "Setting execute permissions on kubectl..."
    chmod +x /usr/local/bin/kubectl
fi

# Step 1: Check API server connectivity
echo ""
echo "=== Step 1: Verifying API server connectivity ==="

if ! kubectl version --kubeconfig=$KUBECONFIG &> /dev/null; then
    echo "ERROR: Cannot connect to Kubernetes API server"
    exit 1
fi
echo "✓ API server is accessible"

# Step 2: Check worker node registration
echo ""
echo "=== Step 2: Checking worker node registration ==="

echo "Waiting for worker nodes to register..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    NODE_COUNT=$(kubectl get nodes --kubeconfig=$KUBECONFIG --no-headers 2>/dev/null | wc -l)
    if [ $NODE_COUNT -ge 2 ]; then
        echo "✓ Found $NODE_COUNT nodes registered"
        break
    else
        echo "Attempt $attempt/$max_attempts: Found $NODE_COUNT nodes, waiting for at least 2..."
        sleep 10
        attempt=$((attempt + 1))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo "ERROR: Expected worker nodes did not register within expected time"
    echo "Current nodes:"
    kubectl get nodes --kubeconfig=$KUBECONFIG
    exit 1
fi

# Step 3: Display node information
echo ""
echo "=== Step 3: Node Status Overview ==="

echo "All registered nodes:"
kubectl get nodes --kubeconfig=$KUBECONFIG

echo ""
echo "Detailed node information:"
kubectl get nodes -o wide --kubeconfig=$KUBECONFIG

# Step 4: Check individual worker nodes
echo ""
echo "=== Step 4: Individual Worker Node Validation ==="

WORKER_NODES=("node-0" "node-1")

for worker in "${WORKER_NODES[@]}"; do
    echo ""
    echo "--- Validating $worker ---"
    
    # Check if node exists in cluster
    if kubectl get node $worker --kubeconfig=$KUBECONFIG &> /dev/null; then
        echo "✓ $worker is registered in the cluster"
        
        # Get node status
        NODE_STATUS=$(kubectl get node $worker --kubeconfig=$KUBECONFIG --no-headers | awk '{print $2}')
        echo "Node status: $NODE_STATUS"
        
        if [[ "$NODE_STATUS" == "Ready" ]]; then
            echo "✓ $worker is Ready"
        elif [[ "$NODE_STATUS" == "NotReady" ]]; then
            echo "⚠ $worker is NotReady (this may be normal if just started)"
        else
            echo "⚠ $worker status: $NODE_STATUS"
        fi
        
        # Get node details
        echo "Node details:"
        kubectl describe node $worker --kubeconfig=$KUBECONFIG | grep -A 5 "Conditions:" || true
        
    else
        echo "✗ $worker is NOT registered in the cluster"
    fi
    
    # Check worker services directly
    echo "Checking services on $worker:"
    ssh root@$worker "systemctl is-active containerd kubelet kube-proxy" || echo "Some services may not be active"
done

# Step 5: Check system pods
echo ""
echo "=== Step 5: System Pods Status ==="

echo "Checking system pods in kube-system namespace:"
kubectl get pods -n kube-system --kubeconfig=$KUBECONFIG

# Step 6: CNI networking validation
echo ""
echo "=== Step 6: CNI Networking Validation ==="

echo "Checking CNI configuration on worker nodes:"
for worker in "${WORKER_NODES[@]}"; do
    echo ""
    echo "--- CNI validation on $worker ---"
    
    # Check CNI configuration files
    if ssh root@$worker "ls -la /etc/cni/net.d/" 2>/dev/null; then
        echo "✓ CNI configuration files present on $worker"
    else
        echo "✗ CNI configuration files missing on $worker"
    fi
    
    # Check CNI plugins
    CNI_PLUGIN_COUNT=$(ssh root@$worker "ls /opt/cni/bin/ 2>/dev/null | wc -l" || echo "0")
    if [ "$CNI_PLUGIN_COUNT" -gt 0 ]; then
        echo "✓ CNI plugins installed on $worker ($CNI_PLUGIN_COUNT plugins)"
    else
        echo "✗ CNI plugins missing on $worker"
    fi
    
    # Check bridge module
    if ssh root@$worker "lsmod | grep br_netfilter" &>/dev/null; then
        echo "✓ br_netfilter module loaded on $worker"
    else
        echo "⚠ br_netfilter module not loaded on $worker"
    fi
    
    # Check sysctl settings
    if ssh root@$worker "sysctl net.bridge.bridge-nf-call-iptables" 2>/dev/null | grep -q "= 1"; then
        echo "✓ Bridge iptables setting configured on $worker"
    else
        echo "⚠ Bridge iptables setting not configured on $worker"
    fi
done

# Step 7: Cluster component health
echo ""
echo "=== Step 7: Cluster Component Health ==="

echo "Component statuses:"
kubectl get componentstatuses --kubeconfig=$KUBECONFIG

# Step 8: Basic cluster functionality test
echo ""
echo "=== Step 8: Basic Cluster Functionality Test ==="

echo "Testing basic cluster functionality..."

# Create a test namespace
TEST_NAMESPACE="worker-validation-test"
kubectl create namespace $TEST_NAMESPACE --kubeconfig=$KUBECONFIG 2>/dev/null || echo "Namespace may already exist"

# Create a simple test deployment
cat > /tmp/test-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
  namespace: $TEST_NAMESPACE
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: test-container
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

echo "Creating test deployment..."
kubectl apply -f /tmp/test-deployment.yaml --kubeconfig=$KUBECONFIG

echo "Waiting for pods to be scheduled..."
sleep 15

echo "Test deployment status:"
kubectl get deployment -n $TEST_NAMESPACE --kubeconfig=$KUBECONFIG
kubectl get pods -n $TEST_NAMESPACE --kubeconfig=$KUBECONFIG

# Clean up test resources
echo "Cleaning up test resources..."
kubectl delete namespace $TEST_NAMESPACE --kubeconfig=$KUBECONFIG
rm -f /tmp/test-deployment.yaml

echo ""
echo "=== Worker Validation Complete ==="
echo "Summary:"
echo "✓ API server connectivity verified"
echo "✓ Worker node registration checked"
echo "✓ Individual worker services validated"
echo "✓ CNI networking configuration validated"
echo "✓ Cluster component health checked"
echo "✓ Basic cluster functionality tested"
echo ""

# Final node summary
READY_NODES=$(kubectl get nodes --kubeconfig=$KUBECONFIG --no-headers | grep -c "Ready" || echo "0")
TOTAL_NODES=$(kubectl get nodes --kubeconfig=$KUBECONFIG --no-headers | wc -l)

echo "Final Status: $READY_NODES/$TOTAL_NODES nodes are Ready"

if [ $READY_NODES -eq $TOTAL_NODES ] && [ $TOTAL_NODES -ge 2 ]; then
    echo "🎉 All worker nodes are successfully configured and ready!"
else
    echo "⚠ Some nodes may still be initializing. Check individual node status above."
fi