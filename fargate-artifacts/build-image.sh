#!/bin/bash
set -e

IMAGE_TAG='42cpoc/pixi_fw:0.0.1'

# Retrieve secrets
echo "===========> Docker build"
docker build . -t $IMAGE_TAG
