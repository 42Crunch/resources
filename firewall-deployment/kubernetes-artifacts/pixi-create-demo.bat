:: 
:: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
:: EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
:: OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
:: 
:: Author: 42Crunch
:: 42Crunch Support - support@42crunch.com
:: Name: pixi-create-demo.bat
:: Purpose: Create the demo environement on K8S platform


@echo off
setlocal enabledelayedexpansion

for /f "delims=" %%x in (.\etc\env) do (set "%%x")

if not defined RUNTIME_NS goto end_with_error

kubectl create namespace %RUNTIME_NS%
:: Create secrets
echo "===========> Creating Secrets"
kubectl create --namespace=%RUNTIME_NS% secret tls firewall-certs --key .\etc\tls\private.key --cert .\etc\tls\cert-fullchain.pem
kubectl create --namespace=%RUNTIME_NS% secret generic generic-pixi-protection-token --from-env-file=.\etc\secret-protection-token
:: Config Map creation
echo "===========> Creating ConfigMap"
kubectl create --namespace=%RUNTIME_NS% configmap firewall-props --from-env-file=.\etc\deployment.properties
:: Deployment (Required App/DB + storage)
echo "===========> Deploying unsecured pixi and database"
kubectl apply --namespace=%RUNTIME_NS% -f pixi-basic-deployment.yaml
:: Deployment (Pixi + FW)
echo "===========> Deploying secured API firewall"
kubectl apply --namespace=%RUNTIME_NS% -f pixi-secured-deployment.yaml

goto end

:end_with_error
    echo "Please configure namespace by setting RUNTIME_NS in etc/env"
    exit /b -1

:end
    exit /b 0
endlocal
