# Kubernetes The Hard Way - Infrastructure Automation

## Project Purpose

This project serves two primary educational purposes:

1. **Kubernetes Deep Learning**: Practice understanding the inner workings of a Kubernetes cluster by manually bootstrapping all components from scratch, following Kelsey Hightower's "Kubernetes The Hard Way" tutorial
2. **AI Agent Workflow**: Explore best practices for working with AI agents on complex, multi-step infrastructure projects while maintaining proper context and task management

Rather than using automated tools like kubeadm, this project builds a production-grade Kubernetes cluster step-by-step to understand:
- Certificate Authority and PKI infrastructure
- etcd cluster bootstrapping
- Kubernetes control plane components (API server, controller manager, scheduler)
- Worker node configuration (kubelet, kube-proxy, container runtime)
- Pod networking and service mesh fundamentals
- Security and encryption configurations

## Architecture

The project provisions a complete Kubernetes cluster on Google Cloud Platform:

- **1 Jumpbox**: Secure access point and administration workstation
- **1 Controller Node**: Runs Kubernetes control plane components
- **2 Worker Nodes**: Execute containerized workloads
- **Custom VPC**: Private network (10.240.0.0/24) with NAT gateway
- **Pod Networking**: Separate subnets per worker (10.200.0.0/24, 10.200.1.0/24)

## Prerequisites

Before running this project, ensure you have:

1. **Git**: Clone this repository
2. **Terraform**: Version 1.0+ installed locally
3. **Google Cloud Platform**:
   - Active GCP project with billing enabled
   - `gcloud` CLI installed and authenticated
   - Compute Engine API enabled
4. **SSH Agent**: Properly configured for agent forwarding

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd k8s-the-hard-way
```

### 2. Configure Google Cloud

```bash
# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set your project (replace with your project ID)
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
```

### 3. Configure Terraform Variables

Edit `infra/variables.tf` or create `infra/terraform.tfvars`:

```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"  # Optional: change region
ssh_user   = "your-username"  # Your SSH username
```

### 4. Provision Infrastructure

```bash
cd infra
terraform init
terraform plan
terraform apply
```

### 5. Verify SSH Connectivity

**Critical Step**: Test SSH agent forwarding to all nodes before proceeding with cluster bootstrap:

```bash
# Get the jumpbox IP
JUMPBOX_IP=$(terraform output -raw jumpbox_ip)

# Test jumpbox connectivity
ssh -A root@$JUMPBOX_IP 'echo "Jumpbox connected"'

# Test connectivity to all cluster nodes from jumpbox
ssh -A root@$JUMPBOX_IP 'for node in server node-0 node-1; do echo "Testing $node..."; ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$node "echo $node connected"; done'
```

**Expected output:**
```
Jumpbox connected
Testing server...
server connected
Testing node-0...
node-0 connected
Testing node-1...
node-1 connected
```

If any connections fail, troubleshoot SSH agent forwarding before proceeding.

### 6. Bootstrap Kubernetes Cluster

Follow the detailed steps in `setup-k8s.md` or use the provided automation scripts:
Simply install claude code and ask your claude code agent to follow the [setup-k8s plan](setup-k8s.md)

If it works claude will create its own plan which will look similar to this:
The bootstrap process includes:
1. Certificate Authority and TLS certificate generation
2. Kubernetes configuration files creation
3. Data encryption key setup
4. etcd cluster initialization
5. Control plane component configuration
6. Worker node setup and joining
7. kubectl configuration for remote access
8. Comprehensive smoke testing

## Learning Outcomes

If you review each of the steps in the original tutorial along with working through this repo, you will understand:

**Kubernetes Internals:**
- How certificates and PKI work in Kubernetes
- etcd's role as the cluster datastore
- Control plane component interactions
- Worker node setup and pod lifecycle
- Networking models and CNI plugins
- Security models and RBAC

**AI Agent Collaboration:**
- Structuring complex projects for AI assistance
- Maintaining context across long-running tasks
- Breaking down infrastructure projects into manageable steps
- Using documentation as agent guidance (CLAUDE.md pattern)

## Troubleshooting

### SSH Connectivity Issues
- Ensure SSH agent is running: `ssh-add -l`
- Verify agent forwarding: `ssh -A` flag is used
- Check firewall rules allow SSH (port 22)

### Terraform Issues
- Verify GCP authentication: `gcloud auth list`
- Check project permissions: Compute Engine Admin role required
- Ensure APIs are enabled: `gcloud services list --enabled`

### Cluster Bootstrap Issues
- Check node connectivity from jumpbox first
- Verify all prerequisite files exist before running scripts
- Review individual component logs via systemctl

## Cleanup

To destroy all infrastructure and clean up:

```bash
cd infra
terraform destroy
# Type 'yes' when prompted
```

**Warning**: This permanently deletes all resources including any data stored on the cluster.

## Contributing

This project demonstrates infrastructure automation patterns and AI agent collaboration. Contributions that improve either the Kubernetes learning experience or agent workflow patterns are welcome.

## References

- [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) by Kelsey Hightower
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## License

This project is for educational purposes. Please respect the licenses of all underlying components and tools.
