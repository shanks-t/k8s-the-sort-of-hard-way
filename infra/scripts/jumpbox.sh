#!/bin/bash

# Get jumpbox IP from Terraform output
JUMPBOX_IP=$(terraform output -raw jumpbox_ip)

if [ -z "$JUMPBOX_IP" ]; then
    echo "Error: Could not get jumpbox IP from Terraform output"
    echo "Make sure you have run 'terraform apply' first"
    exit 1
fi

echo "Connecting to jumpbox at $JUMPBOX_IP with SSH agent forwarding..."
ssh -A root@$JUMPBOX_IP