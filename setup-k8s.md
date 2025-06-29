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

### Pre-Certificate Generation Checks

**Note**: Assume directories exist and cluster nodes are accessible. Only run these verification commands if you encounter errors:

```bash
# Get jumpbox IP
JUMPBOX_IP=$(terraform output -raw jumpbox_ip)

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
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ls -la /root/kubernetes-the-hard-way/encryption-config.yaml'

# Verify encryption config was distributed to controller
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'ssh root@server "ls -la ~/encryption-config.yaml"'

# Check encryption config content
JUMPBOX_IP=$(terraform output -raw jumpbox_ip) && ssh -A root@$JUMPBOX_IP 'cat /root/kubernetes-the-hard-way/encryption-config.yaml'
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

## 7. Complete Workflow

* On successful verification, the cluster’s certificate infrastructure is bootstrapped.
* If any step fails, exit the vm and report the failure results stdout
---

> **Congratulations!** You’ve automated the full bootstrap: infrastructure provisioning, SSH-based distribution of certs, and validation—all orchestrated by the Cloud Code Agent.
