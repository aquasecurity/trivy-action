# Trivy Action

> [GitHub Action](https://github.com/features/actions) for Trivy

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
          docker build -t docker.io/my-organization/my-app:${{ github.sha }}
      - name: Run vulnerability scanner
        uses: aquasecurity/trivy-action@0.0.5
        with:
          image-ref: 'docker.io/my-organization/my-app:${{ github.sha }}'
          format: 'table'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'
```

## Customizing

### inputs

Following inputs can be used as `step.with` keys:

| Name        | Type   | Default                            | Description                                   |
|-------------|--------|------------------------------------|-----------------------------------------------|
| `image-ref` | String |                                    | Image reference, e.g. `alpine:3.10.2`         |
| `format`    | String | `table`                            | Output format (`table`, `json`)               |
| `exit-code` | String | `0`                                | exit code when vulnerabilities were found     |
| `severity`  | String | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` | severities of vulnerabilities to be displayed |
