#!/bin/bash

source ../etc/env

if [ -z "$RUNTIME_NS" ]; then
    echo "Please configure namespace by setting RUNTIME_NS in etc/env"
    exit -1
fi

echo "Deleting artefacts"
kubectl --namespace=$RUNTIME_NS delete cm,pods,services,deployments,secrets --all

if [ "$RUNTIME_NS" != "default" ]; then
    echo "Deleting namespace"
    kubectl delete namespace $RUNTIME_NS
fi
