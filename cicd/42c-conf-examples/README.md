# 42Crunch CI/CD Configuration Examples (`42c-conf.yaml`)

This directory contains curated examples of **`42c-conf.yaml` configuration files** used to control how the 42Crunch API Security Audit behaves inside CI/CD pipelines.

These examples help you:

- Discover OpenAPI files automatically
- Map files to existing APIs in the 42Crunch Platform
- Customize behavior per branch, tag, or pull request
- Enforce quality gates (scores, severity, specific findings)
- Automatically tag APIs
- Control collection naming and sharing
- Gradually harden security enforcement

---

## Table of Contents

1. [What is 42c-conf.yaml](#what-is-42c-confyaml)
2. [How Configuration is Applied](#how-configuration-is-applied)
3. [Directory Overview](#directory-overview)
4. [Configuration Concepts](#configuration-concepts)
5. [Collection Mode](#collection-mode)
6. [Fail Conditions](#fail-conditions)
7. [How to Use These Examples](#how-to-use-these-examples)
8. [Best Practices](#best-practices)

---

## What is 42c-conf.yaml

`42c-conf.yaml` is an optional configuration file that lets you declaratively control how 42Crunch processes OpenAPI files during CI/CD runs.

If present in the repository root used by your pipeline, it overrides default behavior of the integration and allows you to define:

- File discovery rules
- Mapping of files → API UUIDs
- Branch/tag/PR-specific behavior
- Fail conditions
- Tagging
- Collection naming
- Collection sharing

If the file is not present, default behavior is used.

---

## How Configuration is Applied

Priority order:

```
branch → tag → pull request → default
```

Matching blocks override default.

---

## Directory Overview

Each folder demonstrates a focused configuration scenario.

| Path | Purpose |
|------|--------|
| discovery/ | automatic file discovery |
| mapping-and-discovery/ | hybrid mapping + discovery |
| mapping-no-discovery/ | only mapped APIs processed |
| branches-tags-and-prs/ | context-specific rules |
| api_tags/ | automatic tagging |
| fail_on-invalid-contract/ | invalid spec failure |
| fail_on-issue-id/ | fail on specific findings |
| fail_on-scores/ | enforce minimum scores |
| fail_on-severity/ | enforce severity thresholds |
| 42c-conf_all_options.yaml | full example |

---

## Configuration Concepts

### Discovery

Automatically finds OpenAPI files.

```yaml
discovery:
  search:
    - "**/*.yaml"
    - "**/*.json"
    - "!legacy/**"
```

---

### Mapping APIs

Mapping connects repo files to existing APIs.

```yaml
mapping:
  apis/petstore.yaml: "uuid-here"
```

Use mapping when:

- APIs already exist in platform
- You need audit history continuity
- You want stable reporting and governance tracking
- You want to optimize license usage by mapping multiple branches/tags/prs to a single API on our platform

---

### Branch Tag PR Overrides

```yaml
branches:
  main:
    fail_on:
      severity: high

  feature-*:
    fail_on:
      severity: critical
```

Overrides allow stricter policies on protected branches and relaxed policies for development branches.

---

### API Tagging

```yaml
api_tags:
  - team:payments
  - env:prod
```

Tags must already exist in the platform and be valid for their category.

---

## Collection Mode

By default, the CI/CD integration automatically creates a collection using:

```
repository + branch/tag/PR
```

This works well for simple setups, but in real production environments you usually want more control.  
**Collection mode exists to give you that control.**

You should use collection configuration when you need:

- Stable collection names across runs
- Consistent reporting targets
- Separation of environments
- Multi‑team visibility
- Governance‑controlled ownership

Typical enterprise uses:

| Use Case | Why Collection Mode Helps |
|--------|----------------------------|
Stable dashboards | Same collection name every run |
Environment isolation | dev / stage / prod collections |
Team ownership | share collections with specific teams |
Compliance | auditors always review same collection |

Conceptually, a collection configuration might look like:

```yaml
collection:
  name: payments-prod
```

More advanced examples in this directory show:

- branch‑specific collection naming
- centralized collections for production
- shared collections for cross‑team visibility

**Important design principle**

Collections should represent **logical API ownership or lifecycle stage**, not individual CI runs.

Good:

```
payments-prod
payments-dev
core-platform
```

Bad:

```
run-1432
build-abcdef
```

Design collections intentionally — they become reporting anchors across your platform.

---

## Fail Conditions

The `fail_on` configuration allows a pipeline to fail based on audit results.

Supported controls:

- invalid_contract
- severity
- score
- issue_id

Example:

```yaml
fail_on:
  severity: high
```

---

### Important Recommendation — Prefer Security Quality Gates

The `fail_on` mechanism is useful for quick enforcement, but it is **not the recommended long‑term governance model**.

42Crunch provides **Security Quality Gates (SQGs)** which are the preferred and more scalable approach for enforcing policy centrally across APIs:

https://docs.42crunch.com/latest/content/concepts/security_quality_gates.htm

Reasons SQGs are superior:

- centrally managed policy
- reusable across teams
- auditable
- versionable
- consistent across tools
- platform‑enforced (not pipeline‑only)

Because of this, `fail_on` options may eventually become deprecated or discouraged in favor of SQGs for compliance‑driven environments.

Recommended strategy:

| Stage | Approach |
|------|---------|
Early adoption | use fail_on locally |
Maturing teams | migrate rules to SQGs |
Enterprise governance | enforce only SQGs |

Treat `fail_on` as a convenience feature — not your primary compliance enforcement system.

---

## How to Use These Examples

1. Copy example
2. Rename to `42c-conf.yaml`
3. Place in repo root
4. Adjust values
5. Commit and run pipeline

---

## Best Practices

- Start simple → tighten later
- Always map production APIs
- Use tags for governance
- Separate environments into collections
- Treat config as code
- Prefer SQGs for enforcement instead of fail_on rules

