#!/bin/bash

source ../etc/env

if [ -z "$RUNTIME_NS" ]; then
    echo "Please configure namespace by setting RUNTIME_NS in etc/env"
    exit -1
fi

kubectl --namespace=$RUNTIME_NS delete cm,pods,services,deployments,secrets --all
