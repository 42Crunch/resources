# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# 
# 42Crunch Support - support@42crunch.com
#!/bin/bash

source ../etc/env

if [ -z "$RUNTIME_NS" ]; then
    echo "Please configure namespace by setting RUNTIME_NS in etc/env"
    exit -1
fi

kubectl --namespace=$RUNTIME_NS delete cm,pods,services,deployments,secrets --all
kubectl delete namespace $RUNTIME_NS
