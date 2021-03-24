# Trivy Action

> [GitHub Action](https://github.com/features/actions) for [Trivy](https://github.com/aquasecurity/trivy)

[![GitHub Release][release-img]][release]
[![GitHub Marketplace][marketplace-img]][marketplace]
[![License][license-img]][license]

![](docs/images/trivy-action.png)

## Table of Contents

- [Usage](#usage)
  - [Workflow](#workflow)
  - [Docker Image Scanning](#using-trivy-with-github-code-scanning)
  - [Git Repository Scanning](#using-trivy-to-scan-your-git-repo)
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
      - name: Checkout code
        uses: actions/checkout@v2
      
      - name: Build an image from Dockerfile
        run: |
          docker build -t docker.io/my-organization/my-app:${{ github.sha }} .
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'docker.io/my-organization/my-app:${{ github.sha }}'
          format: 'table'
          exit-code: '1'
          ignore-unfixed: true
          vuln-type: 'os,library'
          severity: 'CRITICAL,HIGH'
```

### Using Trivy with GitHub Code Scanning
If you have [GitHub code scanning](https://docs.github.com/en/github/finding-security-vulnerabilities-and-errors-in-your-code/about-code-scanning) available you can use Trivy as a scanning tool as follows:
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
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Build an image from Dockerfile
        run: |
          docker build -t docker.io/my-organization/my-app:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'docker.io/my-organization/my-app:${{ github.sha }}'
          format: 'template'
          template: '@/contrib/sarif.tpl'
          output: 'trivy-results.sarif'

      - name: Upload Trivy scan results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v1
        with:
          sarif_file: 'trivy-results.sarif'
```

You can find a more in-depth example here: https://github.com/aquasecurity/trivy-sarif-demo/blob/master/.github/workflows/scan.yml

### Using Trivy to scan your Git repo
It's also possible to scan your git repos with Trivy's built-in repo scan. This can be handy if you want to run Trivy as a build time check on each PR that gets opened in your repo. This helps you identify potential vulnerablites that might get introduced with each PR.

If you have [GitHub code scanning](https://docs.github.com/en/github/finding-security-vulnerabilities-and-errors-in-your-code/about-code-scanning) available you can use Trivy as a scanning tool as follows:
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
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Build an image from Dockerfile
        run: |
          docker build -t docker.io/my-organization/my-app:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner in repo mode
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          ignore-unfixed: true
          format: 'template'
          template: '@/contrib/sarif.tpl'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL'

      - name: Upload Trivy scan results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v1
        with:
          sarif_file: 'trivy-results.sarif'
```

## Customizing

### inputs

Following inputs can be used as `step.with` keys:

| Name             | Type    | Default                            | Description                                   |
|------------------|---------|------------------------------------|-----------------------------------------------|
| `scan-type`      | String  | `image`                            | Scan type, e.g. `image` or `fs`|
| `input`          | String  |                                    | Tar reference, e.g. `alpine-latest.tar` |
| `image-ref`      | String  |                                    | Image reference, e.g. `alpine:3.10.2`         |
| `scan-ref`       | String  | `/github/workspace/`               | Scan reference, e.g. `/github/workspace/` or `.`|
| `format`         | String  | `table`                            | Output format (`table`, `json`, `template`)   |
| `template`       | String  |                                    | Output template (`@/contrib/sarif.tpl`, `@/contrib/gitlab.tpl`, `@/contrib/junit.tpl`)|
| `output`         | String  |                                    | Save results to a file                        |
| `exit-code`      | String  | `0`                                | Exit code when vulnerabilities were found     |
| `ignore-unfixed` | Boolean | false                              | Ignore unpatched/unfixed vulnerabilities      |
| `vuln-type`      | String  | `os,library`                       | Vulnerability types (os,library)              |
| `severity`       | String  | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` | Severities of vulnerabilities to be displayed |
| `skip-dirs`       | String  |                                   | Comma separated list of directories where traversal is skipped |

[release]: https://github.com/aquasecurity/trivy-action/releases/latest
[release-img]: https://img.shields.io/github/release/aquasecurity/trivy-action.svg?logo=github
[marketplace]: https://github.com/marketplace/actions/aqua-security-trivy
[marketplace-img]: https://img.shields.io/badge/marketplace-trivy--action-blue?logo=github
[license]: https://github.com/aquasecurity/trivy-action/blob/master/LICENSE
[license-img]: https://img.shields.io/github/license/aquasecurity/trivy-action
