# 42Crunch resources 

This repository offers various resources that you can use to get to know and configure 42Crunch Platform and its functions.

The resources include guides, samples files, and examples that you can modify as needed. Just clone the repository and use what you need!

## CI/CD resources

The `cicd/42c-conf-examples` directory contains examples on fine-tuning the CI/CD integration of API Contract Security Audit using the configuration file `42c-conf.yaml`. 

The directory provides examples on each option you can add to the configuration file to change how the integration plugin behaves. Pick the ones you like and compile them into a configuration file of your own.

For more details, see [CI/CD integration](https://docs.42crunch.com/latest/content/concepts/ci_cd_integration.htm).

## Conformance Scan resources

42Crunch supports deploying its conformance scan as a local agent, which can test local APIs which are not exposed through the Internet. 

The conformance scan can be run on any developer's laptop [using Docker](https://docs.42crunch.com/latest/content/concepts/api_contract_conformance_scan.htm#scrollNav-10) but by popular demand, we also developed centralized deployment modes, one based on AWS Batch and the other one based on Kubernetes Jobs.

## API Firewall resources

The `firewall-deployment` directory contains various guides and artifacts to guide you through deploying 42Crunch API Firewall. It is organized as follows:

1. A list of Getting Started guides (as Markdown files) customized for various Kubernetes cloud offerings, including Azure Cloud and Google Cloud as well as Minikube for development purposes.
2. `minikube-artifacts`: The scripts and deployment files you use exclusively as part of the Minikube guide.
3. `kubernetes-artifacts`: The scripts and deployment files you use as part of all other Getting Started guides.
4. `helm-artifacts`: A set of Helm charts you can use to deploy API Firewall in sidecar mode.
5. `OAS-files`: The OpenAPI definitions for the sample Pixi API you protect in the Getting Started guides.
6. `postman-collection`: A Postman collection that lets you to easily invoke the Pixi API used for testing.

Choose your deployment guide and get started!

For more details, see [API Protection](https://docs.42crunch.com/latest/content/concepts/api_protection.htm) and [API Firewall](https://docs.42crunch.com/latest/content/concepts/api_firewall.htm).