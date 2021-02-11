:: 
:: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
:: EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
:: OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
:: 
:: Author: 42Crunch
:: 42Crunch Support - support@42crunch.com

:: Name: pixi-remove-demo.bat
:: Purpose: Remove all the components created on the K8S cluster


@echo off
setlocal enabledelayedexpansion

for /f "delims=" %%x in (..\etc\env) do (set "%%x")

if not defined RUNTIME_NS goto end_with_error

kubectl --namespace=%RUNTIME_NS% delete cm,pods,services,deployments,secrets --all
if %RUNTIME_NS% neq 'default' (
  kubectl delete namespace %RUNTIME_NS%
)

goto end

:end_with_error
    echo "Please configure namespace by setting RUNTIME_NS in etc/env"
    exit /b -1

:end
    exit /b 0
endlocal
