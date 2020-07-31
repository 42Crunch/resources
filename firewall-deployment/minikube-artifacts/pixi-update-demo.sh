#!/bin/bash
source ./etc/env

if [ -z "$RUNTIME_NS" ]; then
    echo "Please configure namespace by setting RUNTIME_NS in env"
    exit -1
fi
# Removing old secret
echo "====> Removing current protection token and deployment"
kubectl delete secret generic-pixi-protection-token --namespace=$RUNTIME_NS
# Removing current deployment
kubectl delete deployment pixi-secured --namespace=$RUNTIME_NS
echo "====> Updating protection token and deployment"
# Create protection secret
kubectl create --namespace=$RUNTIME_NS secret generic generic-pixi-protection-token --from-env-file=./etc/secret-protection-token
# Deployment (Pixi + FW)
kubectl apply --namespace=$RUNTIME_NS -f pixi-secured-deployment.yaml
