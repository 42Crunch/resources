:: Name: pixi-update-demo.bat
:: Purpose: Update the secret and Guardian container deployment on K8S platform
:: Author: 42Crunch

@echo off
setlocal enabledelayedexpansion

for /f "delims=" %%x in (.\etc\env) do (set "%%x")

if not defined RUNTIME_NS goto end_with_error

:: Removing old secret
echo "====> Removing current protection token and deployment"
kubectl delete secret generic-pixi-protection-token --namespace=%RUNTIME_NS%
:: Removing current deployment
kubectl delete deployment pixi-secured --namespace=%RUNTIME_NS%
echo "====> Updating protection token and deployment"
:: Create protection secret
kubectl create --namespace=%RUNTIME_NS% secret generic generic-pixi-protection-token --from-env-file=.\etc\secret-protection-token
:: Deployment (Pixi + FW)
kubectl apply --namespace=%RUNTIME_NS% -f pixi-secured-deployment.yaml

goto end

:end_with_error
    echo "Please configure namespace by setting RUNTIME_NS in etc/env"
    exit /b -1

:end
    exit /b 0
endlocal
