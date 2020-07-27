# Trivy Action

> [GitHub Action](https://github.com/features/actions) for Trivy

[![GitHub Release][release-img]][release]
[![GitHub Marketplace][marketplace-img]][marketplace]
[![License][license-img]][license]

![](docs/images/trivy-action.png)

## Table of Contents

- [Usage](#usage)
  - [Workflow](#workflow)
- [Customizing](#customizing)
  - [Inputs](#inputs)

## Usage

### Workflow

```yaml
name: build
on:
  push:
    branches:
      - master
  pull_request:
jobs:
  build:
    name: Build
    runs-on: ubuntu-18.04
    steps:
      - name: Setup Go
        uses: actions/setup-go@v1
        with:
          go-version: 1.14
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Build an image from Dockerfile
        run: |
          docker build -t docker.io/my-organization/my-app:${{ github.sha }} .
      - name: Run vulnerability scanner
        uses: aquasecurity/trivy-action@0.0.7
        with:
          image-ref: 'docker.io/my-organization/my-app:${{ github.sha }}'
          format: 'table'
          exit-code: '1'
          ignore-unfixed: true
          severity: 'CRITICAL,HIGH'
```

## Customizing

### inputs

Following inputs can be used as `step.with` keys:

| Name             | Type    | Default                            | Description                                   |
|------------------|---------|------------------------------------|-----------------------------------------------|
| `image-ref`      | String  |                                    | Image reference, e.g. `alpine:3.10.2`         |
| `format`         | String  | `table`                            | Output format (`table`, `json`, `template`)   |
| `exit-code`      | String  | `0`                                | Exit code when vulnerabilities were found     |
| `ignore-unfixed` | Boolean | false                              | Ignore unpatched/unfixed vulnerabilities      |
| `severity`       | String  | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` | Severities of vulnerabilities to be displayed |

[release]: https://github.com/aquasecurity/trivy-action/releases/latest
[release-img]: https://img.shields.io/github/release/aquasecurity/trivy-action.svg?logo=github
[marketplace]: https://github.com/marketplace/actions/trivy-vulnerability-scanner
[marketplace-img]: https://img.shields.io/badge/marketplace-trivy--action-blue?logo=github
[license]: https://github.com/aquasecurity/trivy-action/blob/master/LICENSE
[license-img]: https://img.shields.io/github/license/aquasecurity/trivy-action
