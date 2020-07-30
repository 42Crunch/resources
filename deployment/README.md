# Deploying 42Crunch API Firewall on Kubernetes

This directory contains various guides and artifacts to guide you through deploying 42Crunch API Firewall. It is organized as follows:

1. A list of Getting Started guides (as Markdown files) customized for various Kubernetes cloud offerings, including Azure Cloud and Google Cloud as well as Minikube for development purposes.
2. `minikube-artifacts`: The scripts and deployment files you use exclusively as part of the Minikube guide.
3. `kubernetes-artifacts`: The scripts and deployment files you use as part of all other Getting Started guides.
4. `helm-artifacts`: A set of Helm charts you can use to deploy API Firewall in sidecar mode.
5. `OAS-files`: The OpenAPI definitions for the sample Pixi API you protect in the Getting Started guides.
6. `postman-collection`: A Postman collection that lets you to easily invoke the Pixi API used for testing.

Clone this repo, choose your deployment guide and get started!

For more details, see [API Protection](https://docs.42crunch.com/latest/content/concepts/api_protection.htm) and [API Firewall](https://docs.42crunch.com/latest/content/concepts/api_firewall.htm).