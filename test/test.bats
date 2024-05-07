#!/usr/bin/env bats

setup_file() {
  local owner=$GITHUB_REPOSITORY_OWNER
  export TRIVY_DB_REPOSITORY=ghcr.io/${owner}/trivy-db-act:latest
  export TRIVY_JAVA_DB_REPOSITORY=ghcr.io/${owner}/trivy-java-db-act:latest
  export TRIVY_POLICY_BUNDLE_REPOSITORY=ghcr.io/${owner}/trivy-checks-act:latest
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
  run ./entrypoint.sh '-b json' '-h repo.json' '-s secret' '-a repo' '-j https://github.com/krol3/demo-trivy/'
  compare_files repo.json ./test/data/secret-scan/report.json
}

@test "trivy image" {
  # trivy image --severity CRITICAL -o image.test knqyf263/vuln-image:1.2.3
  run ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-h image.test' '-g CRITICAL'
  compare_files image.test ./test/data/image-scan/report
}

@test "trivy config sarif report" {
  # trivy config -f sarif -o  config-sarif.test ./test/data/config-sarif-report
  run ./entrypoint.sh '-a config' '-b sarif' '-h config-sarif.sarif' '-j ./test/data/config-sarif-report/main.tf'
  compare_files config-sarif.sarif ./test/data/config-sarif-report/report.sarif
}

@test "trivy config" {
  # trivy config -f json -o config.json ./test/data/config-scan
  run ./entrypoint.sh '-a config' '-b json' '-j ./test/data/config-scan' '-h config.json'
  compare_files config.json ./test/data/config-scan/report.json
}

@test "trivy rootfs" {
  # trivy rootfs --output rootfs.test ./test/data/rootfs-scan
  # TODO: add data
  run ./entrypoint.sh '-a rootfs' '-j ./test/data/rootfs-scan' '-h rootfs.test'
  compare_files rootfs.test ./test/data/rootfs-scan/report
}

@test "trivy fs" {
  # trivy fs --output fs.test ./test/data/fs-scan
  # TODO: add data
  run ./entrypoint.sh '-a fs' '-j ./test/data/fs-scan' '-h fs.test'
  compare_files fs.test ./test/data/fs-scan/report
}

@test "trivy image with trivyIgnores option" {
  # cat ./test/data/with-ignore-files/.trivyignore1 ./test/data/with-ignore-files/.trivyignore2 > ./trivyignores ; trivy image --severity CRITICAL  --output image-trivyignores.test --ignorefile ./trivyignores knqyf263/vuln-image:1.2.3
  run ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-h image-trivyignores.test' '-g CRITICAL' '-t ./test/data/with-ignore-files/.trivyignore1,./test/data/with-ignore-files/.trivyignore2'
  compare_files image-trivyignores.test ./test/data/with-ignore-files/report
}

@test "trivy image with sbom output" {
  # trivy image --format  github knqyf263/vuln-image:1.2.3
  run ./entrypoint.sh  "-a image" "-b github" "-h github-dep-snapshot.gsbom" "-i knqyf263/vuln-image:1.2.3"
  compare_files github-dep-snapshot.gsbom ./test/data/github-dep-snapshot/report.gsbom
}

@test "trivy image with trivy.yaml config" {
  # trivy --config=./test/data/with-trivy-yaml-cfg/trivy.yaml image alpine:3.10
  run ./entrypoint.sh "-v ./test/data/with-trivy-yaml-cfg/trivy.yaml" "-a image" "-i alpine:3.10"
  compare_files yamlconfig.json ./test/data/with-trivy-yaml-cfg/report.json
}

@test "trivy image with custom docker-host" {
  # trivy image --docker-host unix:///var/run/docker.sock --severity CRITICAL --output image.test knqyf263/vuln-image:1.2.3
  run ./entrypoint.sh '-y unix:///var/run/docker.sock' '-a image' '-i knqyf263/vuln-image:1.2.3' '-h image.test' '-g CRITICAL'
  compare_files image.test ./test/data/image-scan/report
}

@test "trivy config with terraform variables" {
  # trivy config -f json -o tfvars.json --severity  MEDIUM  --tf-vars  ./test/data/with-tf-vars/dev.tfvars ./test/data/with-tf-vars/main.tf  
  run ./entrypoint.sh "-a config"  "-j ./test/data/with-tf-vars/main.tf" "-h tfvars.json" "-g MEDIUM" "-x ./test/data/with-tf-vars/dev.tfvars" "-b json"
  compare_files tfvars.json ./test/data/with-tf-vars/report.json
}