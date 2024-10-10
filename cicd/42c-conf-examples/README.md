# 42Crunch CI/CD Security Audit Configuration

This repository contains the configuration for integrating 42Crunch's API Security Audit with a CI/CD pipeline. It automates the static security testing of your OpenAPI definitions on every push to your Git repository.

## Table of Contents
- [Overview](#overview)
- [Configuration Details](#configuration-details)
  - [Branches Configuration](#branches-configuration)
  - [Tags Configuration](#tags-configuration)
  - [PR Configuration](#pr-configuration)
  - [Mapping and Discovery](#mapping-and-discovery)
  - [API OAS Tagging](#api-tagging)
  - [Fail Conditions](#fail-conditions)
- [Usage](#usage)

## <a name=overview></a>Overview
This configuration allows you to:

- Map your API files in a repository to existing APIs in 42Crunch Platform.
- Discover OpenAPI files based on their filenames and paths.
- Set specific failure conditions based on score, severity, and issue ID.
- Apply different configurations for different branches, tags, and PR targets.
- Automatically tag new APIs created on the 42Crunch Platform.


## <a name=configuration-details></a>Configuration Details

### <a name=branches-configuratio></a>Branches Configuration
The `branches` section defines different configurations for specific branches in your repository. You can set up custom configurations for audit behavior, failure conditions, and API mappings.

```yaml
audit:
  branches:
    main:
      mapping:
        petstore.json: e7cd62ce-1ee9-4320-af33-8bd9519c6f48
      discovery:
        search:
          - '**/*.json'
          - '**/*.yaml'
          - '**/*.yml'
          - '!foo/**'
      fail_on:
        invalid_contract: false
        issue_id:
          - v3-global-security
          - "*schema*"
        score:
          data: 70
          security: 30
        severity: medium
```
### <a name=pr-configuration></a> PR Configuration

This example shows how to configure failure conditions based on the branch name, tag name, or PR target branch.

When the CI/CD plugin starts, it creates an API collection in 42Crunch Platform using the name of the repository and branch, tag, or PR directly from your source control.

If you run the plugin on multiple branches, tags, or PRs in the same repository, the plugin creates a separate API collection for each of them.

You can specify the plugin configuration individually for each branch, tag, or PR in your repository.  You can also use wildcards for the branch names to apply the configuration to all branches with matching names.

You can use wildcards * and ** (see the example below): * matches any character except /, while ** matches any characters including /.

In the example below, the branch called "main" has been configured to fail if the minimum data validation score is under 70, and any branch with a name matching the wildcard pattern feature-* to fail if the data validation score is under 50.  All other branches are caught by the pattern ** and are configured to fail if the data validation score is under 60.

Additionally, you can specify plugin configuration for individual tags and PRs as shown below.
Configurations for PRs are matched based on the PR target branch, so you can, for example, specify that PRs targeting the main branch require higher score than PRs targeting other branches.

```yaml
audit:
  branches:
    main:
      fail_on:
        score:
          data: 70
    "feature-*":
      fail_on:
        score:
          data: 50
    "**":
      fail_on:
        score:
          data: 60
  tags:
    v1.0:
      fail_on:
        score:
          data: 50
    v2.0:
      fail_on:
        score:
          data: 60
    "**":
      fail_on:
        score:
          data: 70
  prs:
    main:
      fail_on:
        score:
          data: 70
    "**":
      fail_on:
        score:
          data: 50
```

### <a name=mapping-and-discovery></a> Mapping and Discovery
This example shows how to map API files in your repository to APIs you already have in 42Crunch Platform.

When the CI/CD plugin starts, it creates an API collection in 42Crunch Platform using the name of the repository and branch directly from your source control.

The plugin uploads any APIs it finds during the discovery phase into this API collection On subsequent runs, the collection is kept is sync with the API files in your source repository.

If you have APIs in other API collections on 42Crunch Platform that you would like like to keep in sync with changes in the files in your source control, you can use mappings for this.

To configure the mapping, you must know the API UUID of the existing API in 42Crunch Platform (you can check it in the API summary on the platform). You list the filenames and the corresponding API UUIDs in the 'mapping' section.

In this example, the sample 'petstore.json' file is mapped, and the plugin uploads it to the platform updating the contents of the API with the UUID 'e7cd62ce-1ee9-4320-af33-8bd9519c6f48' with the contents of the file from the source code repository.

On the other hand, the sample file 'petstore.yaml' is not mapped, so the plugin uploads to its default API collection.

``` yaml
audit:
  branches:
    main:
      mapping:
        petstore.json: e7cd62ce-1ee9-4320-af33-8bd9519c6f48
```

### <a name=api-tagging></a> API OAS Tagging

This feature allows one to associate a category and a tag from said category to APIs found during discovery (or mapping, etc).

``` yaml
audit:
  branches:
    master:
      api_tags:
        - 'category1:tag1'
        - 'category2:tag2'
```

### <a name=fail-conditions></a> Fail Conditions

By default, an API definition that does not fully conform to the OpenAPI Specification (OAS) is reported as a failure.

For example, the sample 'petstore.json' in this example does not have the 'paths' attribute defined, which is something that the OAS requires. Trying to audit this file results in the report "The OpenAPI definition is not valid".

You can switch this off by setting 'invalid_contract' to 'false', as shown below.

```yaml
audit:
  branches:
    main:
      fail_on:
        invalid_contract: false
```

### <a name=Usage></a> Usage

The associated directories contain additional examples on each option for fine-tuning the CI/CD integration using a configuration file called 42c-conf.yaml to change the behavior of the integration plugin:

- `discovery`: How OpenAPI files can be discovered (included or excluded) based on their filenames.
- `fail_on-invalid-contract`: Stop API definitions that do not conform to the OpenAPI Specification (OAS) being reported as failures.
- `fail_on-issue-id`: List the issues that you want always to fail the task.
- `fail_on-scores`: Specify minimum audit scores that APIs must reach in data validation and security.
- `fail_on-severity`: Specify maximum allowed severity for found issues.
- `mapping-and-discovery`: Map API files to your existing APIs in 42Crunch Platform.
- `mapping-no-discovery`: Switch off the discovery phase and only audit specifically mapped API files.
- `branches-tags-and-prs`: Specify different configs for builds running on different branches/tags and PRs
- `api_tags`: Tag APIs with the tags defined in 42Crunch Platform. Only the newly created APIs are tagged. All specified tags must exist on the platform.
- `42c-conf_all_options.yaml`: This file contains an inline noted example of the above options in a single file.

For more details on the plugins that use this file, see [CI/CD integration](https://docs.42crunch.com/latest/content/concepts/ci_cd_integration.htm).
