#!/bin/bash

# Kubernetes The Hard Way - Kubernetes Configuration Files Generation
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-configuration-files.md

set -e

cd /root/kubernetes-the-hard-way

echo "Starting Kubernetes configuration files generation..."

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed or not in PATH"
    exit 1
fi

if [[ ! -f ca.crt ]]; then
    echo "ERROR: ca.crt not found. Please run certificate generation first."
    exit 1
fi

echo "Prerequisites check passed."

# Generate kubelet configuration files for worker nodes
echo "Generating kubelet configuration files for worker nodes..."
for host in node-0 node-1; do
    echo "Creating kubeconfig for $host..."
    
    if [[ ! -f ${host}.crt ]] || [[ ! -f ${host}.key ]]; then
        echo "ERROR: Certificate or key for $host not found"
        exit 1
    fi
    
    kubectl config set-cluster kubernetes-the-hard-way \
        --certificate-authority=ca.crt \
        --embed-certs=true \
        --server=https://server.kubernetes.local:6443 \
        --kubeconfig=${host}.kubeconfig

    kubectl config set-credentials system:node:${host} \
        --client-certificate=${host}.crt \
        --client-key=${host}.key \
        --embed-certs=true \
        --kubeconfig=${host}.kubeconfig

    kubectl config set-context default \
        --cluster=kubernetes-the-hard-way \
        --user=system:node:${host} \
        --kubeconfig=${host}.kubeconfig

    kubectl config use-context default \
        --kubeconfig=${host}.kubeconfig
done

# Generate kube-proxy configuration file
echo "Generating kube-proxy configuration file..."
if [[ ! -f kube-proxy.crt ]] || [[ ! -f kube-proxy.key ]]; then
    echo "ERROR: kube-proxy certificate or key not found"
    exit 1
fi

kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.crt \
    --client-key=kube-proxy.key \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default \
    --kubeconfig=kube-proxy.kubeconfig

# Generate kube-controller-manager configuration file
echo "Generating kube-controller-manager configuration file..."
if [[ ! -f kube-controller-manager.crt ]] || [[ ! -f kube-controller-manager.key ]]; then
    echo "ERROR: kube-controller-manager certificate or key not found"
    exit 1
fi

kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.crt \
    --client-key=kube-controller-manager.key \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default \
    --kubeconfig=kube-controller-manager.kubeconfig

# Generate kube-scheduler configuration file
echo "Generating kube-scheduler configuration file..."
if [[ ! -f kube-scheduler.crt ]] || [[ ! -f kube-scheduler.key ]]; then
    echo "ERROR: kube-scheduler certificate or key not found"
    exit 1
fi

kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.crt \
    --client-key=kube-scheduler.key \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default \
    --kubeconfig=kube-scheduler.kubeconfig

# Generate admin configuration file
echo "Generating admin configuration file..."
if [[ ! -f admin.crt ]] || [[ ! -f admin.key ]]; then
    echo "ERROR: admin certificate or key not found"
    exit 1
fi

kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
    --client-certificate=admin.crt \
    --client-key=admin.key \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=admin.kubeconfig

kubectl config use-context default \
    --kubeconfig=admin.kubeconfig

echo "Kubernetes configuration files generated successfully!"

# Distribute configuration files to worker nodes
echo "Distributing configuration files to worker nodes..."
for host in node-0 node-1; do
    echo "Setting up directories and copying files to $host..."
    
    ssh root@${host} "mkdir -p /var/lib/{kube-proxy,kubelet}"

    scp kube-proxy.kubeconfig \
        root@${host}:/var/lib/kube-proxy/kubeconfig

    scp ${host}.kubeconfig \
        root@${host}:/var/lib/kubelet/kubeconfig
        
    echo "Files copied to $host successfully"
done

# Distribute configuration files to controller node
echo "Distributing configuration files to controller node..."
scp admin.kubeconfig \
    kube-controller-manager.kubeconfig \
    kube-scheduler.kubeconfig \
    root@server:~/

echo "Configuration file distribution completed successfully!"
echo "Generated kubeconfig files:"
ls -la *.kubeconfig

echo ""
echo "=== Summary ==="
echo "✓ Generated kubelet configs for worker nodes (node-0, node-1)"
echo "✓ Generated kube-proxy config"
echo "✓ Generated kube-controller-manager config" 
echo "✓ Generated kube-scheduler config"
echo "✓ Generated admin config"
echo "✓ Distributed configs to worker nodes"
echo "✓ Distributed configs to controller node"
echo ""
echo "Next step: Data Encryption Keys (Lab 06)"