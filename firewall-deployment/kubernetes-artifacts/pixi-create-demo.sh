# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# 
# 42Crunch Support - support@42crunch.com
#!/bin/bash
set -e

source ./etc/env

if [ -z "$RUNTIME_NS" ]; then
    echo "Please configure namespace by setting RUNTIME_NS in env"
    exit -1
fi

kubectl create namespace $RUNTIME_NS
# Create secrets
echo "===========> Creating Secrets"
kubectl create --namespace=$RUNTIME_NS secret tls firewall-certs --key ./etc/tls/private.key --cert ./etc/tls/fullchain-cert-with-ca.pem
kubectl create --namespace=$RUNTIME_NS secret generic generic-pixi-protection-token --from-env-file='./etc/secret-protection-token'
# Config Map creation
echo "===========> Creating ConfigMap"
kubectl create --namespace=$RUNTIME_NS configmap firewall-props --from-env-file='./etc/deployment.properties'
# Deployment (Required App/DB + storage)
echo "===========> Deploying unsecured pixi and database"
kubectl apply --namespace=$RUNTIME_NS -f pixi-basic-deployment.yaml
# Deployment (Pixi + FW)
echo "===========> Deploying secured API firewall"
kubectl apply --namespace=$RUNTIME_NS -f pixi-secured-deployment.yaml
