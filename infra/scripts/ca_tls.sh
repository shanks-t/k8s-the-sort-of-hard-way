#!/bin/bash

# Kubernetes The Hard Way - Certificate Authority and TLS Certificate Generation
# Based on: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md

set -e

cd /root/kubernetes-the-hard-way

echo "Starting Certificate Authority and TLS certificate generation..."

# Generate CA private key
openssl genrsa -out ca.key 4096

# Generate CA certificate
openssl req -x509 -new -sha512 -noenc \
  -key ca.key -days 3653 \
  -config ca.conf \
  -out ca.crt

echo "CA certificate generated successfully"

# Define certificates to generate
certs=(
  "admin" "node-0" "node-1"
  "kube-proxy" "kube-scheduler"
  "kube-controller-manager"
  "kube-api-server"
  "service-accounts"
)

# Generate certificates for each component
echo "Generating certificates for components..."
for i in ${certs[*]}; do
  echo "Generating certificate for: $i"
  
  openssl genrsa -out "${i}.key" 4096

  openssl req -new -key "${i}.key" -sha256 \
    -config "ca.conf" -section ${i} \
    -out "${i}.csr"

  openssl x509 -req -days 3653 -in "${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "${i}.crt"
done

echo "Certificate generation completed successfully!"

# Distribute certificates to nodes
echo "Distributing certificates to cluster nodes..."

# Create kubelet directories and copy certificates to worker nodes
for host in node-0 node-1; do
  echo "Setting up certificates for $host..."
  ssh root@${host} mkdir -p /var/lib/kubelet/

  scp ca.crt root@${host}:/var/lib/kubelet/

  scp ${host}.crt \
    root@${host}:/var/lib/kubelet/kubelet.crt

  scp ${host}.key \
    root@${host}:/var/lib/kubelet/kubelet.key
done

# Copy certificates to controller
echo "Copying certificates to controller..."
scp \
  ca.key ca.crt \
  kube-api-server.key kube-api-server.crt \
  service-accounts.key service-accounts.crt \
  root@server:~/

echo "Certificate distribution completed successfully!"
echo "Generated certificates:"
ls -la *.crt *.key