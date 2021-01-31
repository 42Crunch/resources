#!/bin/bash
set -e

IMAGE_TAG='749000XXXXXX.dkr.ecr.eu-west-1.amazonaws.com/42cfirewall:1.0.1-tls'

# Retrieve secrets
echo "===========> Docker build"
docker build . -t $IMAGE_TAG
