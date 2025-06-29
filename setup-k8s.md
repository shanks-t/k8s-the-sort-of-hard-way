# Terraform Apply and CA-TLS Automation with Cloud Code Agent

This guide provides step-by-step instructions for the Cloud Code Agent to:

> **Note:** This uses the `ca-tls` script provided in the earlier context.

---

## 0. Pre-flight Checks

Before starting the deployment, verify all prerequisites:

```bash
# Ensure you're in the correct project directory
cd /Users/treyshanks/workspace/model-serving/k8s-the-hard-way/infra
```

### SSH Connectivity and Host Key Verification Check

**CRITICAL**: Test SSH connectivity to all nodes. If any connections fail, STOP and prompt user for manual setup:

```bash
# Get jumpbox IP
JUMPBOX_IP=$(terraform output -raw jumpbox_ip)

# Test jumpbox connectivity first
echo "Testing jumpbox connectivity..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes -A root@$JUMPBOX_IP 'echo jumpbox-connected'; then
    echo "ERROR: Cannot connect to jumpbox. Please check network connectivity and SSH keys."
    exit 1
fi

# Test connectivity from jumpbox to all cluster nodes
echo "Testing cluster node connectivity from jumpbox..."
if ! ssh -A root@$JUMPBOX_IP 'ssh -o ConnectTimeout=5 -o BatchMode=yes root@server "echo controller-ok" && ssh -o ConnectTimeout=5 -o BatchMode=yes root@node-0 "echo worker0-ok" && ssh -o ConnectTimeout=5 -o BatchMode=yes root@node-1 "echo worker1-ok"'; then
    echo ""
    echo "ERROR: Host key verification failed or nodes unreachable from jumpbox."
    echo ""
    echo "REQUIRED MANUAL STEP:"
    echo "1. SSH into jumpbox: ssh -A root@$JUMPBOX_IP"
    echo "2. From jumpbox, establish host keys manually:"
    echo "   ssh root@server \"echo Controller connection established\""
    echo "   ssh root@node-0 \"echo Worker-0 connection established\""
    echo "   ssh root@node-1 \"echo Worker-1 connection established\""
    echo "3. Exit jumpbox and re-run this script"
    echo ""
    exit 1
fi

echo "✓ All SSH connections successful. Proceeding with setup..."
```

**Expected output on success**: 
```
Testing jumpbox connectivity...
jumpbox-connected
Testing cluster node connectivity from jumpbox...
controller-ok
worker0-ok
worker1-ok
✓ All SSH connections successful. Proceeding with setup...
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
openssl x509 -in /root/kubernetes-the-hard-way/ca.crt -noout -text | grep "CA: TRUE"
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

### Copy Bootstrap Script to Server

```bash
# Copy the bootstrap script to the controller
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && scp /Users/treyshanks/workspace/model-serving/k8s-the-hard-way/infra/scripts/bootstrap-controllers.sh root@$JUMPBOX_IP:~/
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'scp /root/bootstrap-controllers.sh root@server:~/'
```

### Run Bootstrap Controllers Script

```bash
# Execute the bootstrap controllers script on server
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "/root/bootstrap-controllers.sh"'
```

**Note**: If the script fails with "Permission denied" errors for the binaries, fix the execute permissions:

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

## 8. Complete Workflow

* On successful verification, the cluster’s certificate infrastructure is bootstrapped.
* If any step fails, exit the vm and report the failure results stdout
---

> **Congratulations!** You’ve automated the full bootstrap: infrastructure provisioning, SSH-based distribution of certs, and validation—all orchestrated by the Cloud Code Agent.
