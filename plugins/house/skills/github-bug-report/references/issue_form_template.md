# Ready-to-commit GitHub issue form

Offer this when the user wants their whole team to file consistent bugs. Commit
it at `.github/ISSUE_TEMPLATE/bug_report.yml`. GitHub's Forms format renders real
input fields and makes chosen fields required, so reporters can't skip the parts
developers need.

Tune the `Platform` dropdown and labels to the project. Below is a generic version
covering backend / frontend / mobile / multiplatform.

```yaml
name: Bug Report
description: Report a bug so it can be reproduced and fixed.
title: "[Bug] <short summary>"
labels: ["bug"]
body:
  - type: markdown
    attributes:
      value: "Thanks for filing a bug! The more precise the repro steps and version, the faster it gets fixed."
  - type: textarea
    id: description
    attributes:
      label: Description
      description: What's broken and why it matters, in a sentence or two.
    validations:
      required: true
  - type: textarea
    id: steps
    attributes:
      label: Steps to Reproduce
      description: Exact, numbered steps from a known starting state.
      placeholder: |
        1.
        2.
        3.
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
    validations:
      required: true
  - type: textarea
    id: actual
    attributes:
      label: Actual Behavior
      description: Include exact error text if any.
    validations:
      required: true
  - type: dropdown
    id: platform
    attributes:
      label: Platform
      options:
        - Backend / API
        - Frontend / Web
        - Mobile
        - Multiplatform / Multi-flavour
    validations:
      required: true
  - type: input
    id: version
    attributes:
      label: Version / Build
      description: Release tag, build number, or commit SHA. Include flavour/variant for mobile.
      placeholder: "e.g. 3.4.1 (build 218), production flavour"
    validations:
      required: true
  - type: textarea
    id: environment
    attributes:
      label: Environment
      description: OS, browser/device, region, service — whatever fits the platform.
    validations:
      required: true
  - type: dropdown
    id: frequency
    attributes:
      label: Reproducibility
      options: ["Always", "Intermittent", "Happened once"]
    validations:
      required: true
  - type: dropdown
    id: severity
    attributes:
      label: Severity
      options: ["Blocker", "High", "Medium", "Low"]
    validations:
      required: true
  - type: textarea
    id: evidence
    attributes:
      label: Evidence
      description: Screenshots, recording, logs, stack trace, crash ID, or request/response.
    validations:
      required: false
```
