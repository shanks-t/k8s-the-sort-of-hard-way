# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project follows the "Kubernetes The Hard Way" tutorial by Kelsey Hightower (https://github.com/kelseyhightower/kubernetes-the-hard-way) for learning Kubernetes fundamentals through manual cluster setup. The tutorial emphasizes understanding each component rather than using automated tools.

The Terraform infrastructure in this repository provisions Google Cloud resources for the tutorial's requirements:

- 1 jumpbox instance for secure access
- 1 controller node running Kubernetes control plane
- 2 worker nodes for running workloads
- Custom VPC network (10.240.0.0/24) with NAT gateway
- Firewall rules for SSH, internal communication, and Kubernetes API access

## Architecture

All infrastructure is defined in the `/infra` directory using Terraform modules:

- `main.tf`: Core compute instances (jumpbox, controller, workers) with static IP assignments
- `network.tf`: VPC, subnet, router, and NAT gateway configuration  
- `firewall.tf`: Security rules for SSH (port 22), Kubernetes API (port 6443), internal traffic, and ICMP
- `variables.tf`: Configurable parameters including GCP project, region, instance counts, and SSH keys
- `outputs.tf`: IP addresses for accessing the provisioned instances
- `provider.tf`: Google Cloud provider configuration

## Common Commands

### Infrastructure Management
```bash
# Initialize Terraform
cd infra && terraform init

# Plan infrastructure changes
cd infra && terraform plan

# Apply infrastructure
cd infra && terraform apply

# Destroy infrastructure
cd infra && terraform destroy

# Show current state
cd infra && terraform show

# Get output values (IP addresses)
cd infra && terraform output
```

## Key Configuration

- **Project ID**: creature-vision (default)
- **Region**: us-central1 (default)  
- **Network CIDR**: 10.240.0.0/24
- **Static IPs**: Jumpbox (.9), Controller (.10), Workers (.20, .21)
- **SSH User**: trey (configurable via variables.tf)
- **Instance Type**: e2-medium (configurable)

The jumpbox serves as the entry point to the private Kubernetes network and has a public IP for external access.

## Tutorial Reference

This project implements the infrastructure for the "Kubernetes The Hard Way" tutorial, which consists of 13 sequential labs:

1. **Prerequisites** - Tool installation and setup
2. **Jumpbox** - Administrative workstation setup  
3. **Compute Resources** - VM provisioning (covered by this Terraform)
4. **Certificate Authority** - PKI and TLS certificate generation
5. **Kubernetes Configuration Files** - kubeconfig file creation
6. **Data Encryption Keys** - etcd encryption at rest
7. **Bootstrapping etcd** - etcd cluster setup
8. **Bootstrapping Kubernetes Controllers** - Control plane component setup
9. **Bootstrapping Kubernetes Workers** - Worker node configuration
10. **Configuring kubectl** - Remote cluster access
11. **Pod Network Routes** - Container networking setup
12. **Smoke Test** - Cluster functionality verification
13. **Cleanup** - Resource teardown

After provisioning infrastructure with Terraform, continue with Lab 4 (Certificate Authority) in the original tutorial. The tutorial targets Kubernetes v1.32.x with containerd v2.1.x runtime.