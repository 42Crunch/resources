#!/bin/bash

# Create secrets
echo "===========> Creating AWS Secrets "
aws secretsmanager create-secret --name 42c-protection-token --secret-string `cat etc/secret-protection-token`
