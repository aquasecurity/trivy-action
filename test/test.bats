#!/usr/bin/env bats

bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-file

setup_file() {
  setup_trivy_env
  docker pull knqyf263/vuln-image:1.2.3 1>&3 2>&3
  trivy image --download-db-only 1>&3 2>&3
}

setup() {
  export TRIVY_OUTPUT="$BATS_TEST_TMPDIR/output.test"
  export TRIVY_SKIP_DB_UPDATE=true
  export TRIVY_SKIP_JAVA_DB_UPDATE=true
}

teardown() {
  reset_envs
}

setup_trivy_env() {
  local owner="${GITHUB_REPOSITORY_OWNER:-aquasecurity}"

  export TRIVY_DB_REPOSITORY="ghcr.io/${owner}/trivy-db-act:latest"
  export TRIVY_JAVA_DB_REPOSITORY="ghcr.io/${owner}/trivy-java-db-act:latest"
  export TRIVY_CHECKS_BUNDLE_REPOSITORY="ghcr.io/${owner}/trivy-checks-act:latest"

  export TRIVY_LIST_ALL_PKGS=false
  export TRIVY_DISABLE_VEX_NOTICE=true
  export TRIVY_SKIP_VERSION_CHECK=true
  export TRIVY_DISABLE_TELEMETRY=true
}

reset_envs() {
  local var
  for var in $(env | grep '^TRIVY_\|^INPUT_' | cut -d= -f1); do
    unset "$var"
  done
  rm -f trivy_envs.txt
}

compare_files() {
  local actual="$1"
  local expected="$2"

  # Some fields should be removed as they are environment dependent 
  # and may cause undesirable results when comparing files.
  normalize_report "$actual"
  normalize_report "$expected"
  
  if [ "${UPDATE_GOLDEN}" = "1" ]; then
    cp "$actual" "$expected"
    echo "Updated golden file: $expected"
  else
    run diff "$actual" "$expected"
    echo "$output"
    assert_files_equal "$actual" "$expected"
  fi

  rm -f "$actual"
}


normalize_report() {
  local file="$1"

  case "$TRIVY_FORMAT" in
    json)
      apply_jq_filter "$file" \
        'del(.CreatedAt, .ReportID)'
      ;;
    sarif)
      apply_jq_filter "$file" \
        'del(.runs[].tool.driver.version)
         | del(.runs[].originalUriBaseIds)'
      ;;
    github)
      apply_jq_filter "$file" \
        'del(.detector.version)
         | del(.scanned)
         | del(.job)
         | del(.ref)
         | del(.sha)'
      ;;
  esac
}

apply_jq_filter() {
  local file="$1"
  local filter="$2"
  local tmp="$BATS_TEST_TMPDIR/jq.tmp"

  jq "$filter" "$file" > "$tmp" && mv "$tmp" "$file"
}

run_test_case_compare() {
  local expected_file="$1"

  run ./entrypoint.sh
  assert_success

  compare_files "$TRIVY_OUTPUT" "$expected_file"
}

run_test_case_fails() {
  local expected_msg="$1"

  run ./entrypoint.sh
  assert_failure

  if [ -n "$expected_msg" ]; then
    assert_output --partial "$expected_msg"
  fi
}

@test "trivy repo with securityCheck secret only" {
  # trivy repo -f json -o repo.test --scanners=secret https://github.com/krol3/demo-trivy/
  export TRIVY_FORMAT=json TRIVY_SCANNERS=secret INPUT_SCAN_TYPE=repo INPUT_SCAN_REF="https://github.com/krol3/demo-trivy/"
  run_test_case_compare ./test/data/secret-scan/report.json
}

@test "trivy image" {
  # trivy image --severity CRITICAL -o image.test knqyf263/vuln-image:1.2.3
  export TRIVY_SEVERITY=CRITICAL INPUT_SCAN_TYPE=image INPUT_SCAN_REF=knqyf263/vuln-image:1.2.3
  run_test_case_compare ./test/data/image-scan/report
}

@test "trivy config sarif report" {
  # trivy config -f sarif -o  config-sarif.test ./test/data/config-sarif-report
  export TRIVY_FORMAT=sarif INPUT_SCAN_TYPE=config INPUT_SCAN_REF=./test/data/config-sarif-report
  run_test_case_compare ./test/data/config-sarif-report/report.sarif
}

@test "trivy config" {
  # trivy config -f json -o config.json ./test/data/config-scan
  export TRIVY_FORMAT=json INPUT_SCAN_TYPE=config INPUT_SCAN_REF=./test/data/config-scan
  run_test_case_compare ./test/data/config-scan/report.json
}

@test "trivy rootfs" {
  # trivy rootfs --output rootfs.test ./test/data/rootfs-scan
  # TODO: add data
  export INPUT_SCAN_TYPE=rootfs INPUT_SCAN_REF=./test/data/rootfs-scan
  run_test_case_compare ./test/data/rootfs-scan/report
}

@test "trivy fs" {
  # trivy fs --output fs.test ./test/data/fs-scan
  # TODO: add data
  export INPUT_SCAN_TYPE=fs INPUT_SCAN_REF=./test/data/fs-scan
  run_test_case_compare ./test/data/fs-scan/report
}

@test "trivy image with trivyIgnores option" {
  # cat ./test/data/with-ignore-files/.trivyignore1 ./test/data/with-ignore-files/.trivyignore2 > ./trivyignores ; trivy image --severity CRITICAL  --output image-trivyignores.test --ignorefile ./trivyignores knqyf263/vuln-image:1.2.3
  export TRIVY_SEVERITY=CRITICAL INPUT_SCAN_TYPE=image INPUT_IMAGE_REF=knqyf263/vuln-image:1.2.3 INPUT_TRIVYIGNORES="./test/data/with-ignore-files/.trivyignore1,./test/data/with-ignore-files/.trivyignore2"
  run_test_case_compare ./test/data/with-ignore-files/report
}

@test "trivy image with .trivyignore.yaml" {
  # trivy image --severity CRITICAL  --output with-yaml-ignore-file.test --ignorefile ./test/data/with-yaml-ignore-file/.trivyignore.yaml
  export TRIVY_SEVERITY=CRITICAL INPUT_SCAN_TYPE=image INPUT_IMAGE_REF=knqyf263/vuln-image:1.2.3 INPUT_TRIVYIGNORES=./test/data/with-yaml-ignore-file/.trivyignore.yaml
  run_test_case_compare ./test/data/with-yaml-ignore-file/report
}

@test "trivy image with sbom output" {
  # trivy image --format github knqyf263/vuln-image:1.2.3
  export TRIVY_FORMAT=github INPUT_SCAN_TYPE=image INPUT_SCAN_REF=knqyf263/vuln-image:1.2.3
  run_test_case_compare ./test/data/github-dep-snapshot/report.gsbom
}

@test "trivy image with trivy.yaml config" {
  # trivy --config=./test/data/with-trivy-yaml-cfg/trivy.yaml image alpine:3.10
  export TRIVY_CONFIG=./test/data/with-trivy-yaml-cfg/trivy.yaml TRIVY_FORMAT=json INPUT_SCAN_TYPE=image INPUT_SCAN_REF=alpine:3.10
  run_test_case_compare ./test/data/with-trivy-yaml-cfg/report.json
}

@test "trivy image with custom docker-host" {
  # trivy image --docker-host unix:///var/run/docker.sock --severity CRITICAL --output image.test knqyf263/vuln-image:1.2.3
  export TRIVY_SEVERITY=CRITICAL INPUT_SCAN_TYPE=image INPUT_SCAN_REF=knqyf263/vuln-image:1.2.3 TRIVY_DOCKER_HOST=unix:///var/run/docker.sock
  run_test_case_compare ./test/data/image-scan/report
}

@test "trivy config with terraform variables" {
  # trivy config -f json -o tfvars.json --severity  MEDIUM  --tf-vars  ./test/data/with-tf-vars/dev.tfvars ./test/data/with-tf-vars/main.tf
  export TRIVY_FORMAT=json TRIVY_SEVERITY=MEDIUM INPUT_SCAN_TYPE=config INPUT_SCAN_REF=./test/data/with-tf-vars/main.tf TRIVY_TF_VARS=./test/data/with-tf-vars/dev.tfvars
  run_test_case_compare ./test/data/with-tf-vars/report.json
}

@test "trivy image via environment file" {
  # trivy image --severity CRITICAL --output image.test knqyf263/vuln-image:1.2.3
  # Action injects inputs into the script via environment variables
  echo "export TRIVY_SEVERITY=CRITICAL" >> trivy_envs.txt
  echo "export INPUT_SCAN_TYPE=image" >> trivy_envs.txt
  echo "export INPUT_SCAN_REF=knqyf263/vuln-image:1.2.3" >> trivy_envs.txt 
  run_test_case_compare ./test/data/image-scan/report
}

@test "trivy image via environment file overrides env leakages" {
  # trivy image --severity CRITICAL --output image.test knqyf263/vuln-image:1.2.3
  # Action injects inputs into the script via environment variables
  # If caller mixes old and new trivy-action version they could still have env leakage so verify that env vars already
  # in the env are overridden by those from the envs file
  export INPUT_SCAN_REF=no/such-image:1.2.3
  echo "export TRIVY_SEVERITY=CRITICAL" >> trivy_envs.txt
  echo "export INPUT_SCAN_TYPE=image" >> trivy_envs.txt
  echo "export INPUT_SCAN_REF=knqyf263/vuln-image:1.2.3" >> trivy_envs.txt 
  run_test_case_compare ./test/data/image-scan/report
}

@test "error if ignorefile does not exist" {
  missing_file="$BATS_TEST_TMPDIR/missing.ignore"

  export INPUT_TRIVYIGNORES="$missing_file" \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run_test_case_fails "cannot find ignorefile '$missing_file'"
}

@test "error with mixed yaml and plain ignore files" {
  plain_ignore="$BATS_TEST_TMPDIR/ignore-plain"
  yaml_ignore="$BATS_TEST_TMPDIR/ignore.yaml"
  
  touch "$plain_ignore" "$yaml_ignore"

  export INPUT_TRIVYIGNORES="$plain_ignore,$yaml_ignore" \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run_test_case_fails "Cannot mix YAML and plain trivy ignore files"
}

@test "error if multiple YAML files provided" {
  yaml1="$BATS_TEST_TMPDIR/ignore1.yaml"
  yaml2="$BATS_TEST_TMPDIR/ignore2.yaml"
  touch "$yaml1" "$yaml2"

  export INPUT_TRIVYIGNORES="$yaml1,$yaml2" \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run_test_case_fails "Multiple YAML ignore files provided"
}

@test "works with a single YAML file" {
  yaml="$BATS_TEST_TMPDIR/ignore.yaml"
  touch "$yaml"

  export INPUT_TRIVYIGNORES="$yaml" \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run ./entrypoint.sh
  assert_output --partial "Using YAML ignorefile '$yaml'"
}

@test "works with multiple plain ignore files" {
  plain1="$BATS_TEST_TMPDIR/ignore1"
  plain2="$BATS_TEST_TMPDIR/ignore2"
  echo "CVE-1" > "$plain1"
  echo "CVE-2" > "$plain2"

  trivy_output="$BATS_TEST_TMPDIR/trivy-output.test"

  export INPUT_TRIVYIGNORES="$plain1,$plain2" \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run ./entrypoint.sh
  assert_output --partial "Found ignorefile '$plain1'"
  assert_output --partial "Found ignorefile '$plain2'"
}
