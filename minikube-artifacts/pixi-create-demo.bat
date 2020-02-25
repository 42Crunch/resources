:: Name: pixi-create-demo.bat
:: Purpose: Create the demo environement on K8S platform
:: Author: 42Crunch

@echo off
setlocal enabledelayedexpansion

for /f "delims=" %%x in (.\etc\env) do (set "%%x")
for /f "delims=" %%x in (.\etc\secret-docker-registry) do (set "%%x")

if not defined RUNTIME_NS goto end_with_error

kubectl create namespace %RUNTIME_NS%
:: Create secrets
kubectl create --namespace=%RUNTIME_NS% secret docker-registry docker-registry-creds --docker-server="%REGISTRY_SERVER%" --docker-username="%REGISTRY_USERNAME%" --docker-password="%REGISTRY_PASSWORD%" --docker-email="%REGISTRY_EMAIL%"
kubectl create --namespace=%RUNTIME_NS% secret tls firewall-certs --key .\etc\tls\private.key --cert .\etc\tls\cert-fullchain.pem
kubectl create --namespace=%RUNTIME_NS% secret generic generic-pixi-protection-token --from-env-file=.\etc\secret-protection-token
:: Config Map creation
kubectl create --namespace=%RUNTIME_NS% configmap firewall-props --from-env-file=.\etc\deployment.properties
:: Deployment (Required App/DB + storage)
kubectl apply --namespace=%RUNTIME_NS% -f pixi-basic-deployment.yaml
:: Deployment (Pixi + FW)
kubectl apply --namespace=%RUNTIME_NS% -f pixi-secured-deployment.yaml

goto end

:end_with_error
    echo "Please configure namespace by setting RUNTIME_NS in etc/env"
    exit /b -1

:end
    exit /b 0
endlocal
