#!/bin/bash

# Kubernetes The Hard Way - Kubernetes Configuration Files Generation
# Based on: https://github.com/kelseyhightower/docs/06-data-encryption-keys.md

# generate encryption key
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

# create encryption-config.yaml
envsubst < kubernetes-the-hard-way/configs/encryption-config.yaml \
  > encryption-config.yaml

# comp encryption-config.yaml to controller
scp encryption-config.yaml root@server:~/
