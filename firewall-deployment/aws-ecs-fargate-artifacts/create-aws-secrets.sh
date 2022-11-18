#!/bin/bash

# Retrieve environment variables
. ./variables.env

# Create the 42c-tutorial-protection-token secret in AWS Secrets Manager if it does not exist. Else, update it.

aws secretsmanager describe-secret --secret-id 42c-tutorial-protection-token 2>/dev/null >/dev/null
retVal=$?
if [ $retVal -ne 0 ]; then
	echo "===========> Creating AWS Secrets "
	aws secretsmanager create-secret --name 42c-tutorial-protection-token --secret-string $XLIIC_PROTECTION_TOKEN
else
	echo "===========> Updating 42c-tutorial-protection-token AWS secret "
	aws secretsmanager update-secret --secret-id 42c-tutorial-protection-token --secret-string $XLIIC_PROTECTION_TOKEN
fi


