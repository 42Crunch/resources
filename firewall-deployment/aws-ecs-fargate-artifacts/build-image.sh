#!/bin/bash

# Fail on any error
set -e

# Retrieve environment variables
. ./variables.env

AWS_ECR=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
AWS_REPOSITORY_URI=$AWS_ECR/$AWS_REPOSITORY

# Retrieve login password from AWS ECR, and use it to docker login
echo "===========> Docker login to AWS ECR"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ECR"

# Build the image (base 42Crunch firewall image + SSL cert/key)
echo "===========> Docker build"
echo $AWS_REPOSITORY_URI
docker build . -t $AWS_REPOSITORY_URI

# Push the image to AWS ECR
echo "===========> Docker push"
docker push $AWS_REPOSITORY_URI
