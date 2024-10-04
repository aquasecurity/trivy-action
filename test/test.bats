#!/usr/bin/env bats

setup_file() {
  local owner=$GITHUB_REPOSITORY_OWNER
  export TRIVY_DB_REPOSITORY=ghcr.io/${owner}/trivy-db-act:latest
  export TRIVY_JAVA_DB_REPOSITORY=ghcr.io/${owner}/trivy-java-db-act:latest
  export TRIVY_CHECKS_BUNDLE_REPOSITORY=ghcr.io/${owner}/trivy-checks-act:latest
}

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file
}

function remove_json_fields() {
  local file="$1"
  if [[ "$file" == *.json ]]; then
      jq 'del(.CreatedAt)' "$file" > tmp && mv tmp "$file"
  fi
}

function remove_sarif_fields() {
  local file="$1"
  if [[ "$file" == *.sarif ]]; then
      jq 'del(.runs[].tool.driver.version) | del(.runs[].originalUriBaseIds)' "$file" > tmp && mv tmp "$file"
  fi
}

function remove_github_fields() {
  local file="$1"
  if [[ "$file" == *.gsbom  ]]; then
      jq 'del(.detector.version) | del(.scanned) | del(.job) | del(.ref) | del(.sha)' "$file" > tmp && mv tmp "$file"
  fi
}

function reset_envs() {
  local var
  for var in $(env | grep '^TRIVY_\|^INPUT_' | cut -d= -f1); do
    unset "$var"
  done
}

function compare_files() {
  local file1="$1"
  local file2="$2"

  # Some fields should be removed as they are environment dependent 
  # and may cause undesirable results when comparing files.
  remove_json_fields "$file1"
  remove_json_fields "$file2"

  remove_sarif_fields "$file1"
  remove_sarif_fields "$file2"

  remove_github_fields "$file1"
  remove_github_fields "$file2"
  
  run diff "$file1" "$file2"
  echo "$output"
  assert_files_equal "$file1" "$file2"
}

@test "trivy repo with securityCheck secret only" {
  # trivy repo -f json -o repo.test --scanners=secret https://github.com/krol3/demo-trivy/
  export TRIVY_FORMAT=json TRIVY_OUTPUT=repo.json TRIVY_SCANNERS=secret INPUT_SCAN_TYPE=repo INPUT_SCAN_REF="https://github.com/krol3/demo-trivy/"
  ./entrypoint.sh
  compare_files repo.json ./test/data/secret-scan/report.json
  reset_envs
}

@test "trivy image" {
  # trivy image --severity CRITICAL -o image.test knqyf263/vuln-image:1.2.3
  export TRIVY_OUTPUT=image.test TRIVY_SEVERITY=CRITICAL INPUT_SCAN_TYPE=image INPUT_SCAN_REF=knqyf263/vuln-image:1.2.3
  ./entrypoint.sh
  compare_files image.test ./test/data/image-scan/report
  reset_envs
}

@test "trivy config sarif report" {
  # trivy config -f sarif -o  config-sarif.test ./test/data/config-sarif-report
  export TRIVY_FORMAT=sarif TRIVY_OUTPUT=config-sarif.sarif INPUT_SCAN_TYPE=config INPUT_SCAN_REF=./test/data/config-sarif-report
  ./entrypoint.sh
  compare_files config-sarif.sarif ./test/data/config-sarif-report/report.sarif
  reset_envs
}

@test "trivy config" {
  # trivy config -f json -o config.json ./test/data/config-scan
  export TRIVY_FORMAT=json TRIVY_OUTPUT=config.json INPUT_SCAN_TYPE=config INPUT_SCAN_REF=./test/data/config-scan
  ./entrypoint.sh
  compare_files config.json ./test/data/config-scan/report.json
  reset_envs
}

@test "trivy rootfs" {
  # trivy rootfs --output rootfs.test ./test/data/rootfs-scan
  # TODO: add data
  export TRIVY_OUTPUT=rootfs.test INPUT_SCAN_TYPE=rootfs INPUT_SCAN_REF=./test/data/rootfs-scan
  ./entrypoint.sh
  compare_files rootfs.test ./test/data/rootfs-scan/report
  reset_envs
}

@test "trivy fs" {
  # trivy fs --output fs.test ./test/data/fs-scan
  # TODO: add data
  export TRIVY_OUTPUT=fs.test INPUT_SCAN_TYPE=fs INPUT_SCAN_REF=./test/data/fs-scan
  ./entrypoint.sh
  compare_files fs.test ./test/data/fs-scan/report
  reset_envs
}

@test "trivy image with trivyIgnores option" {
  # cat ./test/data/with-ignore-files/.trivyignore1 ./test/data/with-ignore-files/.trivyignore2 > ./trivyignores ; trivy image --severity CRITICAL  --output image-trivyignores.test --ignorefile ./trivyignores knqyf263/vuln-image:1.2.3
  export TRIVY_OUTPUT=image-trivyignores.test TRIVY_SEVERITY=CRITICAL INPUT_SCAN_TYPE=image INPUT_IMAGE_REF=knqyf263/vuln-image:1.2.3 INPUT_TRIVYIGNORES="./test/data/with-ignore-files/.trivyignore1,./test/data/with-ignore-files/.trivyignore2"
  ./entrypoint.sh
  compare_files image-trivyignores.test ./test/data/with-ignore-files/report
  reset_envs
}

@test "trivy image with sbom output" {
  # trivy image --format github knqyf263/vuln-image:1.2.3
  export TRIVY_FORMAT=github TRIVY_OUTPUT=github-dep-snapshot.gsbom INPUT_SCAN_TYPE=image INPUT_SCAN_REF=knqyf263/vuln-image:1.2.3
  ./entrypoint.sh
  compare_files github-dep-snapshot.gsbom ./test/data/github-dep-snapshot/report.gsbom
  reset_envs
}

@test "trivy image with trivy.yaml config" {
  # trivy --config=./test/data/with-trivy-yaml-cfg/trivy.yaml image alpine:3.10
  export TRIVY_CONFIG=./test/data/with-trivy-yaml-cfg/trivy.yaml INPUT_SCAN_TYPE=image INPUT_SCAN_REF=alpine:3.10
  ./entrypoint.sh
  compare_files yamlconfig.json ./test/data/with-trivy-yaml-cfg/report.json
  reset_envs
}

@test "trivy image with custom docker-host" {
  # trivy image --docker-host unix:///var/run/docker.sock --severity CRITICAL --output image.test knqyf263/vuln-image:1.2.3
  export TRIVY_OUTPUT=image.test TRIVY_SEVERITY=CRITICAL INPUT_SCAN_TYPE=image INPUT_SCAN_REF=knqyf263/vuln-image:1.2.3 TRIVY_DOCKER_HOST=unix:///var/run/docker.sock
  ./entrypoint.sh
  compare_files image.test ./test/data/image-scan/report
  reset_envs
}

@test "trivy config with terraform variables" {
  # trivy config -f json -o tfvars.json --severity  MEDIUM  --tf-vars  ./test/data/with-tf-vars/dev.tfvars ./test/data/with-tf-vars/main.tf
  export TRIVY_FORMAT=json TRIVY_SEVERITY=MEDIUM TRIVY_OUTPUT=tfvars.json INPUT_SCAN_TYPE=config INPUT_SCAN_REF=./test/data/with-tf-vars/main.tf TRIVY_TF_VARS=./test/data/with-tf-vars/dev.tfvars
  ./entrypoint.sh
  compare_files tfvars.json ./test/data/with-tf-vars/report.json
  reset_envs
}