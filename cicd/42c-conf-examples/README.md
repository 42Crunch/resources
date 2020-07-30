# CI/CD integration with 42Crunch API Contract Security Audit

You can integrate Security Audit with different CI/CD solutions using plugins and automate the static security testing of your OpenAPI definitions from a simple push to your Git repository.

This directory contains examples on each option for fine-tuning the CI/CD integration using a configuration file called `42c-conf.yaml` to change the behaviour of the integration plugin: 

- `discovery`: How OpenAPI files can be discovered (included or excluded) based on their filenames.
- `fail_on-invalid-contract`: Stop API definitione that do not conform to the OpenAPI Specification (OAS) being reported as failures.
- `fail_on-issue-id`: List the issues that you want always to fail the task.
- `fail_on-scores`: Specify minimum audit scores that APIs must reach in data validation and security.
- `fail_on-severity`: Specify maximum allowed severity for found issues.
- `mapping-and-discovery`: Map API files to your existing APIs in 42Crunch Platform.
- `mapping-no-discovery`: Switch off the discovery phase except for specifically mapped API files.

Each example also comes with sample files (and directories where applicable) to make it easier to understand and test them in practice.

Pick the ones you want and compile them into a configuration file of your own.

For more details, see [CI/CD integration](https://docs.42crunch.com/latest/content/concepts/ci_cd_integration.htm).