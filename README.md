# Deploying 42Crunch API Firewall on Kubernetes

This repository contains various guides and artefacts to guide you through deploying 42Crunch API Firewall. It is organized as follows:

1. A list of Getting Started guides customized for various Kubernetes cloud offerings, including Azure Cloud and Google Cloud as well as Minikube for development purposes. There is also a generic guide (generic-kubernetes) you can use for other Kubernetes deployments, including custom on-premises deployments. Once a Kubernetes cluster is up and running, the steps to deploy and manage 42Crunch API Firewall are basically the same regardless of the environment.
2. minikube-artifacts: the scripts and deployment files you use exclusively as part of the Minikube guide.
3. kubernetes-artifacts: the scripts and deployment files you use as part of all other Getting Started guides.
4. helm-artifacts: a set of Helm charts you can use to deploy API Firewall in sidecar mode.
5. OAS-files: the OpenAPI definitions for the sample Pixi API you protect in the Getting Started guides.
6. Postman-collection: a Postman collection that lets you to easily invoke the Pixi API used for testing.

Clone this repo,  choose your deployment guide and get started!
