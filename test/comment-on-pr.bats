#!/usr/bin/env bats

bats_load_library bats-support
bats_load_library bats-assert

setup_file() {
  setup_trivy_env
  # Download DB for fs scans
  "${TRIVY_CMD:-trivy}" fs --no-progress --download-db-only 1>&3 2>&3
}

setup() {
  export TRIVY_SKIP_DB_UPDATE=true
  export TRIVY_SKIP_JAVA_DB_UPDATE=true
}

teardown() {
  reset_envs
}

setup_trivy_env() {
  export TRIVY_DB_REPOSITORY="ghcr.io/aquasecurity/trivy-db@sha256:7f8b879d4c23469b09c874b18d64a7eedea95f0ce08ea1862a783dc8d799be6f"
  export TRIVY_JAVA_DB_REPOSITORY="ghcr.io/aquasecurity/trivy-java-db@sha256:f60faf3353edb6556f676c83c8b26d8a60398feab31ab2ec591537707a7354ba"
  export TRIVY_CHECKS_BUNDLE_REPOSITORY="ghcr.io/aquasecurity/trivy-checks@sha256:b63166ca02aa09e30a5127320384d7bd0d2760dc19bab3ab7041a6070114ba45" # v2.2.0

  export TRIVY_LIST_ALL_PKGS=false
  export TRIVY_DISABLE_VEX_NOTICE=true
  export TRIVY_SKIP_VERSION_CHECK=true
  export TRIVY_DISABLE_TELEMETRY=true
}

reset_envs() {
  local var
  for var in $(env | grep '^TRIVY_\|^INPUT_\|^GITHUB_' | cut -d= -f1); do
    unset "$var"
  done
  rm -f trivy_envs.txt
  # Re-set trivy env for next test
  setup_trivy_env
}

setup_mock_curl() {
  local mock_dir="$BATS_TEST_TMPDIR/mock-bin"
  mkdir -p "$mock_dir"
  cat > "$mock_dir/curl" <<'MOCK_CURL'
#!/usr/bin/env bash
# Return empty array for comment listing (GET with per_page)
if [[ "$*" == *"per_page"* ]]; then
  echo "[]"
  exit 0
fi
# Return 201 for POST/PATCH (when -w '%{http_code}' is used)
if [[ "$*" == *"-w"* ]]; then
  echo "201"
  exit 0
fi
exit 0
MOCK_CURL
  chmod +x "$mock_dir/curl"
  export PATH="$mock_dir:$PATH"
}

@test "comment-on-pr skips on non-PR event" {
  local event_file="$BATS_TEST_TMPDIR/push-event.json"
  echo '{"ref": "refs/heads/main"}' > "$event_file"

  export TRIVY_OUTPUT="$BATS_TEST_TMPDIR/output.test"
  export INPUT_COMMENT_ON_PR=true \
         INPUT_GITHUB_TOKEN=fake-token \
         GITHUB_EVENT_PATH="$event_file" \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run ./entrypoint.sh
  assert_success
  assert_output --partial "No associated pull request found. Skipping PR comment."
}

@test "comment-on-pr skips without GITHUB_TOKEN" {
  local event_file="$BATS_TEST_TMPDIR/pr-event.json"
  echo '{"pull_request": {"number": 1}}' > "$event_file"

  export TRIVY_OUTPUT="$BATS_TEST_TMPDIR/output.test"
  export INPUT_COMMENT_ON_PR=true \
         INPUT_GITHUB_TOKEN="" \
         GITHUB_EVENT_PATH="$event_file" \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run ./entrypoint.sh
  assert_success
  assert_output --partial "GITHUB_TOKEN is not available. Skipping PR comment."
}

@test "comment-on-pr posts comment on pull_request event" {
  setup_mock_curl

  local event_file="$BATS_TEST_TMPDIR/pr-event.json"
  echo '{"pull_request": {"number": 42}}' > "$event_file"

  export TRIVY_OUTPUT="$BATS_TEST_TMPDIR/output.test"
  export INPUT_COMMENT_ON_PR=true \
         INPUT_GITHUB_TOKEN=fake-token \
         GITHUB_EVENT_PATH="$event_file" \
         GITHUB_REPOSITORY=test/repo \
         GITHUB_API_URL=https://api.github.com \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run ./entrypoint.sh
  assert_success
  assert_output --partial "Created new PR comment."
}

@test "comment-on-pr extracts PR number from workflow_run event" {
  setup_mock_curl

  local event_file="$BATS_TEST_TMPDIR/workflow-run-event.json"
  echo '{"workflow_run": {"pull_requests": [{"number": 99}]}}' > "$event_file"

  export TRIVY_OUTPUT="$BATS_TEST_TMPDIR/output.test"
  export INPUT_COMMENT_ON_PR=true \
         INPUT_GITHUB_TOKEN=fake-token \
         GITHUB_EVENT_PATH="$event_file" \
         GITHUB_REPOSITORY=test/repo \
         GITHUB_API_URL=https://api.github.com \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run ./entrypoint.sh
  assert_success
  assert_output --partial "Created new PR comment."
}

@test "comment-on-pr ignores plain issue events" {
  local event_file="$BATS_TEST_TMPDIR/issue-event.json"
  echo '{"issue": {"number": 10}}' > "$event_file"

  export TRIVY_OUTPUT="$BATS_TEST_TMPDIR/output.test"
  export INPUT_COMMENT_ON_PR=true \
         INPUT_GITHUB_TOKEN=fake-token \
         GITHUB_EVENT_PATH="$event_file" \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run ./entrypoint.sh
  assert_success
  assert_output --partial "No associated pull request found. Skipping PR comment."
}

@test "comment-on-pr works for issue_comment on a PR" {
  setup_mock_curl

  local event_file="$BATS_TEST_TMPDIR/issue-comment-pr-event.json"
  echo '{"issue": {"number": 15, "pull_request": {"url": "https://api.github.com/repos/test/repo/pulls/15"}}}' > "$event_file"

  export TRIVY_OUTPUT="$BATS_TEST_TMPDIR/output.test"
  export INPUT_COMMENT_ON_PR=true \
         INPUT_GITHUB_TOKEN=fake-token \
         GITHUB_EVENT_PATH="$event_file" \
         GITHUB_REPOSITORY=test/repo \
         GITHUB_API_URL=https://api.github.com \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run ./entrypoint.sh
  assert_success
  assert_output --partial "Created new PR comment."
}

@test "comment-on-pr creates temp output and still prints to stdout" {
  setup_mock_curl

  local event_file="$BATS_TEST_TMPDIR/pr-event.json"
  echo '{"pull_request": {"number": 1}}' > "$event_file"

  # No TRIVY_OUTPUT — script should create a temp file and still print to stdout
  export INPUT_COMMENT_ON_PR=true \
         INPUT_GITHUB_TOKEN=fake-token \
         GITHUB_EVENT_PATH="$event_file" \
         GITHUB_REPOSITORY=test/repo \
         GITHUB_API_URL=https://api.github.com \
         INPUT_SCAN_TYPE=fs \
         INPUT_SCAN_REF=./test/data/fs-scan

  run ./entrypoint.sh
  assert_success
  assert_output --partial "Running Trivy with options:"
  assert_output --partial "Created new PR comment."
}

@test "comment-on-pr still posts comment when scan fails" {
  setup_mock_curl

  local event_file="$BATS_TEST_TMPDIR/pr-event.json"
  echo '{"pull_request": {"number": 1}}' > "$event_file"

  export TRIVY_OUTPUT="$BATS_TEST_TMPDIR/output.test"
  export INPUT_COMMENT_ON_PR=true \
         INPUT_GITHUB_TOKEN=fake-token \
         GITHUB_EVENT_PATH="$event_file" \
         GITHUB_REPOSITORY=test/repo \
         GITHUB_API_URL=https://api.github.com \
         INPUT_SCAN_TYPE=image \
         INPUT_SCAN_REF=no-such-image:latest

  run ./entrypoint.sh
  # Scan fails but comment should still be posted (not abort)
  assert_output --partial "Posting scan results as PR comment..."
  assert_output --partial "Created new PR comment."
}
