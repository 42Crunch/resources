#!/bin/bash

# Create secrets
echo "===========> Creating AWS Secrets "
aws secretsmanager create-secret --name pixi-fw-token --secret-string `cat etc/secret-protection-token`
