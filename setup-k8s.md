# Terraform Apply and CA-TLS Automation with Cloud Code Agent

This guide provides step-by-step instructions for the Cloud Code Agent to:

## 0. Pre-flight Checks

Before starting the deployment, verify all prerequisites:

```bash
# Ensure you're in the correct project directory
cd /Users/treyshanks/workspace/model-serving/k8s-the-hard-way/infra
```

### SSH Connectivity and Host Key Verification Check

**CRITICAL**: Test SSH connectivity to all nodes. If any connections fail, STOP and prompt user for manual setup:

```bash
# Test jumpbox connectivity
JUMPBOX_IP=$(terraform output -raw jumpbox_ip)
ssh -A root@$JUMPBOX_IP 'echo "Jumpbox connected"'

# Test cluster node connectivity from jumpbox
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'for node in server node-0 node-1; do echo "Testing $node..."; ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$node "echo $node connected"; done'
```

**Expected output on success**:
```
Jumpbox connected
Testing server...
server connected
Testing node-0...
node-0 connected
Testing node-1...
node-1 connected
```

### Pre-Certificate Generation Checks

**Note**: Only run these verification commands if you encounter errors during setup:

```bash
# Only run these if errors occur during certificate generation:
# ssh -A root@$JUMPBOX_IP 'ls -la /root/kubernetes-the-hard-way/'
# ssh -A root@$JUMPBOX_IP 'cat /root/kubernetes-the-hard-way/ca.conf | head -20'
```

### Run Certificate Generation Script

```bash
# Execute the CA/TLS distribution script on jumpbox
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP '/root/ca-tls.sh'
```

**Note**: Output may show "Host key verification failed" messages when the script connects to worker nodes for the first time. This is normal - the script handles this automatically and continues successfully.
---

## 3. Verify CA and TLS Certificates

After running `/root/ca_tls.sh`, perform the following checks **inside the jumpbox** (or via remote SSH commands) to ensure everything succeeded.

### 3.1 Validate the CA Certificate

```bash
# Inspect the CA certificate details
openssl x509 -in /root/kubernetes-the-hard-way/ca.crt -noout -text | grep -A 1 "Basic Constraints"
```

* Should output: `X509v3 Basic Constraints: critical\n   CA:TRUE`

### 3.2 Validate Component Certificates Against the CA

Verify certificates against the CA on each node (hostnames configured by setup scripts):

```bash
# Verify certificates against CA on jumpbox
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && for cert in *.crt; do echo "Verifying $cert..."; openssl verify -CAfile ca.crt "$cert"; done'

# Verify API server certificate on controller node
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "openssl verify -CAfile /root/ca.crt /root/kube-api-server.crt"'

# Verify kubelet certificates on worker nodes
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'for node in node-0 node-1; do echo "Verifying kubelet cert on $node..."; ssh root@${node} "openssl verify -CAfile /var/lib/kubelet/ca.crt /var/lib/kubelet/kubelet.crt"; done'
```

* Expected output: `<path/to/cert>: OK`

### 3.3 Check Certificate Expiration Dates

```bash
# List expiration for all generated certs
for cert in /root/kubernetes-the-hard-way/*.crt; do \
  echo "$cert expires on:"; \
  openssl x509 -in "$cert" -noout -enddate; \
done
```

* Confirm the `notAfter=` date is as expected (e.g., 10 years from generation).

---

## 4. Generate Kubernetes Configuration Files

After certificates are validated, create kubeconfig files for all Kubernetes components:

### Run Kubeconfig Setup Script

```bash
# Execute the kubeconfig setup script on jumpbox
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP '/root/kubeconfig-setup.sh'
```

**Note**: Output may show "Host key verification failed" messages when the script connects to worker nodes and controller for the first time. This is normal - the script handles this automatically and continues successfully.

### Verify Kubeconfig Files

```bash
# Verify kubeconfig files were generated
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ls -la /root/kubernetes-the-hard-way/*.kubeconfig'

# Verify files were distributed to worker nodes
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'for node in node-0 node-1; do echo "Checking $node:"; ssh root@${node} "ls -la /var/lib/kubelet/kubeconfig /var/lib/kube-proxy/kubeconfig"; done'

# Verify files were distributed to controller
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "ls -la ~/admin.kubeconfig ~/kube-controller-manager.kubeconfig ~/kube-scheduler.kubeconfig"'
```

Expected output: All kubeconfig files should exist in their respective locations.

---

## 5. Generate Data Encryption Keys

After kubeconfig files are created, generate encryption keys for data at rest:

### Run Encryption Setup Script

```bash
# Execute the encryption setup script on jumpbox
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP '/root/encryption-setup.sh'
```

### Verify Encryption Configuration

```bash
# Verify encryption config file was generated
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ls -la /root/encryption-config.yaml'

# Verify encryption config was distributed to controller
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "ls -la ~/encryption-config.yaml"'

# Check encryption config content
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cat /root/encryption-config.yaml'
```

Expected output: Encryption configuration file should exist on jumpbox and be copied to controller node.

---

## 6. Bootstrap etcd Cluster

After encryption keys are configured, bootstrap the etcd cluster on the controller node:

### Copy etcd Binaries to Controller

```bash
# Copy etcd binaries from jumpbox to controller (certificates already copied from ca-tls script)
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && scp downloads/controller/etcd downloads/client/etcdctl root@server:~/'
```

### Run etcd Setup on Controller

```bash
# Execute etcd setup script on controller node
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "/root/etcd-setup.sh"'
```

### Verify etcd Cluster

```bash
# Verify etcd service is running
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "systemctl status etcd"'

# Verify etcd cluster membership
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "etcdctl member list"'
```

Expected output: etcd service should be active and cluster should show one member (controller).

---

## 7. Bootstrap Kubernetes Controllers (Lab 08)

After etcd cluster is running, bootstrap the Kubernetes control plane components:

### Copy Controller Binaries and Configs to Server

```bash
# Copy Kubernetes controller binaries and configuration files from jumpbox to server
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && scp downloads/controller/kube-apiserver downloads/controller/kube-controller-manager downloads/controller/kube-scheduler downloads/client/kubectl units/kube-apiserver.service units/kube-controller-manager.service units/kube-scheduler.service configs/kube-scheduler.yaml configs/kube-apiserver-to-kubelet.yaml root@server:~/'
```

### Run Bootstrap Controllers Script

```bash
# Execute the bootstrap controllers script on server
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "/root/bootstrap-controllers.sh"'
```

```bash
# Fix binary permissions if needed
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "chmod +x /usr/local/bin/kube-apiserver /usr/local/bin/kube-controller-manager /usr/local/bin/kube-scheduler /usr/local/bin/kubectl"'

# Restart services after fixing permissions
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "systemctl restart kube-apiserver kube-controller-manager kube-scheduler"'
```

### Verify Controllers

```bash
# Check controller service status
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "systemctl is-active kube-apiserver kube-controller-manager kube-scheduler"'

# Test API server version endpoint (use correct CA path)
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "curl --cacert /var/lib/kubernetes/ca.crt https://server.kubernetes.local:6443/version"'

# Apply RBAC configuration (skip validation due to certificate issues)
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "kubectl apply -f kube-apiserver-to-kubelet.yaml --kubeconfig admin.kubeconfig --validate=false"'
```

**Expected output**:
- All three controller services should be "active"
- Version endpoint should return Kubernetes v1.32.x JSON response
- RBAC configuration should be applied successfully

**Known Issue**: `kubectl cluster-info` may fail with certificate verification errors. This doesn't affect controller functionality - the API server is working correctly as verified by the curl command. This will be resolved in later worker node setup steps.

---

## 8. Bootstrap Kubernetes Workers (Lab 09)

After the control plane is running, bootstrap the worker nodes:

### Copy Node-Specific Configuration Files and Certificates

```bash
# Copy node-specific configuration files to node-0 (subnet 10.200.0.0/24)
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && sed "s|SUBNET|10.200.0.0/24|g" configs/10-bridge.conf > 10-bridge.conf && sed "s|SUBNET|10.200.0.0/24|g" configs/kubelet-config.yaml > kubelet-config.yaml && scp 10-bridge.conf kubelet-config.yaml node-0.crt node-0.key node-0.kubeconfig kube-proxy.kubeconfig ca.crt root@node-0:~/'

# Copy node-specific configuration files to node-1 (subnet 10.200.1.0/24)
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && sed "s|SUBNET|10.200.1.0/24|g" configs/10-bridge.conf > 10-bridge.conf && sed "s|SUBNET|10.200.1.0/24|g" configs/kubelet-config.yaml > kubelet-config.yaml && scp 10-bridge.conf kubelet-config.yaml node-1.crt node-1.key node-1.kubeconfig kube-proxy.kubeconfig ca.crt root@node-1:~/'
```

### Copy Worker Binaries and Unit Files

```bash
# Copy worker binaries and systemd units to node-0
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && scp downloads/worker/crictl downloads/worker/kube-proxy downloads/worker/kubelet downloads/worker/runc downloads/worker/containerd downloads/worker/containerd-shim-runc-v2 downloads/worker/containerd-stress units/containerd.service units/kubelet.service units/kube-proxy.service configs/kube-proxy-config.yaml configs/containerd-config.toml configs/99-loopback.conf root@node-0:~/'

# Copy CNI plugins to node-0
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && tar -czf cni-plugins.tar.gz -C downloads/cni-plugins . && scp cni-plugins.tar.gz root@node-0:~/'

# Copy worker binaries and systemd units to node-1
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && scp downloads/worker/crictl downloads/worker/kube-proxy downloads/worker/kubelet downloads/worker/runc downloads/worker/containerd downloads/worker/containerd-shim-runc-v2 downloads/worker/containerd-stress units/containerd.service units/kubelet.service units/kube-proxy.service configs/kube-proxy-config.yaml configs/containerd-config.toml configs/99-loopback.conf root@node-1:~/'

# Copy CNI plugins to node-1
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && scp cni-plugins.tar.gz root@node-1:~/'
```

### Run Bootstrap Workers Script

```bash
# Execute the bootstrap workers script on node-0
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@node-0 "/root/bootstrap-workers.sh"'

# Fix missing config files if services fail to start
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@node-0 "cp /root/kubelet-config.yaml /var/lib/kubelet/ 2>/dev/null || true; cp /root/kube-proxy-config.yaml /var/lib/kube-proxy/ 2>/dev/null || true; systemctl restart kubelet kube-proxy"'

# Execute the bootstrap workers script on node-1
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@node-1 "/root/bootstrap-workers.sh"'

# Fix missing config files if services fail to start
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@node-1 "cp /root/kubelet-config.yaml /var/lib/kubelet/ 2>/dev/null || true; cp /root/kube-proxy-config.yaml /var/lib/kube-proxy/ 2>/dev/null || true; systemctl restart kubelet kube-proxy"'
```

### Verify Worker Nodes

```bash
# Check worker node status from controller
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "kubectl get nodes --kubeconfig admin.kubeconfig"'

# Check worker services on each node
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@node-0 "systemctl is-active containerd kubelet kube-proxy"'
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@node-1 "systemctl is-active containerd kubelet kube-proxy"'
```

**Expected output**: Both worker nodes should show as "Ready" and all services should be "active"

---

## 9. Configure kubectl for Remote Access (Lab 10)

After worker nodes are operational, configure kubectl for remote cluster management:

### Setup kubectl Configuration

```bash
# Configure kubectl on jumpbox for remote cluster access
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.crt --embed-certs=true --server=https://server.kubernetes.local:6443'

# Set admin credentials
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && kubectl config set-credentials admin --client-certificate=admin.crt --client-key=admin.key'

# Create and use context
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cd /root/kubernetes-the-hard-way && kubectl config set-context kubernetes-the-hard-way --cluster=kubernetes-the-hard-way --user=admin && kubectl config use-context kubernetes-the-hard-way'
```

### Verify Remote Access

```bash
# Check Kubernetes version
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'kubectl version'

# List cluster nodes
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'kubectl get nodes'

# Check cluster info
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'kubectl cluster-info'
```

**Expected output**:
- kubectl version should show both client and server v1.32.3
- `kubectl get nodes` should list node-0 and node-1 as Ready
- `kubectl cluster-info` should show control plane URL

---

## 10. Pod Network Routes (Lab 11)

Pod network routes are automatically configured via Terraform using Google Cloud routes.

### Pod CIDR Assignments
- **node-0**: 10.200.0.0/24
- **node-1**: 10.200.1.0/24

### Verify Pod Network Routes

```bash
# Check GCP-level routes (should be automatically created by Terraform)
gcloud compute routes list --filter="network:kubernetes"
```

**Expected output**: Should show `pod-route-node-0` and `pod-route-node-1` routes

### Test Pod Connectivity (Optional)

If you want to test pod-to-pod communication across nodes, you can deploy test pods:

```bash
# Deploy test pods on different nodes
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'kubectl run test-pod-0 --image=busybox --restart=Never --node-selector="kubernetes.io/hostname=node-0" -- sleep 3600'
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'kubectl run test-pod-1 --image=busybox --restart=Never --node-selector="kubernetes.io/hostname=node-1" -- sleep 3600'

# Test cross-node pod communication
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'kubectl get pods -o wide'
```

**Note**: Pod network routes are handled at the Google Cloud Platform level through Terraform configuration in `network.tf`. This eliminates the need for manual IP route configuration on individual VMs.

---

## 11. Smoke Test (Lab 12)

After configuring pod network routes, run comprehensive smoke tests to verify all Kubernetes cluster functionality:

### 11.1 Data Encryption Test

Verify that secrets are encrypted at rest in etcd:

```bash
# Create a test secret
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'kubectl create secret generic kubernetes-the-hard-way --from-literal="mykey=mydata"'

# Verify the secret is encrypted in etcd storage
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "etcdctl --endpoints=http://127.0.0.1:2379 get /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"'
```

**Expected output**: Should show `k8s:enc:aescbc:v1:key1` prefix indicating AES-CBC encryption is working.

### 11.2 Deployments Test

Verify deployment creation and pod scheduling:

```bash
# Create nginx deployment
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'kubectl create deployment nginx --image=nginx:latest'

# Verify pod creation and assignment
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'kubectl get pods -l app=nginx -o wide'
```

**Expected output**: Pod should be running on one of the worker nodes with an IP from the pod CIDR range.

### 11.3 Port Forwarding Test

Verify port forwarding functionality:

```bash
# Test port forwarding (runs in background and tests connectivity)
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}") && timeout 10 kubectl port-forward $POD_NAME 8080:80 >/dev/null 2>&1 & sleep 2 && curl -m 3 http://127.0.0.1:8080 | head -n 3; pkill -f "kubectl port-forward"'
```

**Expected output**: Should return nginx HTML content indicating port forwarding is working.

### 11.4 Logs Test

Verify log retrieval functionality:

```bash
# Retrieve nginx pod logs
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}") && kubectl logs $POD_NAME'
```

**Expected output**: Should show nginx startup logs and any access logs from previous tests.

### 11.5 Exec Test

Verify command execution inside containers:

```bash
# Execute command in nginx container
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}") && kubectl exec $POD_NAME -- nginx -v'
```

**Expected output**: Should return nginx version information.

### 11.6 Services Test

Verify service creation and external accessibility:

```bash
# Expose nginx deployment as NodePort service
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'kubectl expose deployment nginx --port 80 --type NodePort'

# Get service details
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'NODE_PORT=$(kubectl get svc nginx -o jsonpath="{.spec.ports[0].nodePort}") && NODE_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].spec.nodeName}") && echo "Node: $NODE_NAME, Port: $NODE_PORT"'

# Test service accessibility
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'NODE_PORT=$(kubectl get svc nginx -o jsonpath="{.spec.ports[0].nodePort}") && NODE_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].spec.nodeName}") && curl -m 5 http://${NODE_NAME}:${NODE_PORT} | head -n 3'
```

**Expected output**: Should return nginx HTML content via the NodePort service, confirming service networking is functional.

**Smoke Test Summary**: All tests passing indicates:
- ✅ Data encryption at rest is working
- ✅ Pod scheduling and deployments function correctly
- ✅ Network connectivity and port forwarding work
- ✅ Log retrieval is operational
- ✅ Container exec functionality works
- ✅ Service networking and external access function properly

---

## 12. Cleanup (Lab 13)

When you're done with the Kubernetes cluster, you can tear down all infrastructure:

### Destroy Infrastructure

```bash
# Destroy all Google Cloud resources provisioned by Terraform
terraform destroy

# Confirm destruction when prompted by typing 'yes'
```

**Warning**: This will permanently delete all infrastructure including:
- Compute instances (jumpbox, controller, worker nodes)
- VPC network and subnets
- Firewall rules
- Routes and NAT gateway
- All data stored on the instances

---

## 13. Complete Workflow

* On successful verification, the cluster’s certificate infrastructure is bootstrapped.
* If any step fails, exit the vm and report the failure results stdout
---

> **Congratulations!** You’ve automated the full bootstrap: infrastructure provisioning, SSH-based distribution of certs, and validation—all orchestrated by the Cloud Code Agent.
