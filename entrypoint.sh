#!/bin/bash
set -euo pipefail

# Read TRIVY_* envs from file, previously they were written to the GITHUB_ENV file but GitHub Actions automatically 
# injects those into subsequent job steps which means inputs from one trivy-action invocation were leaking over to 
# any subsequent invocation which led to unexpected/undesireable behaviour from a user perspective
# See #422 for more context around this
if [ -f ./trivy_envs.txt ]; then
  source ./trivy_envs.txt
fi

# Set artifact reference
scanType="${INPUT_SCAN_TYPE:-image}"
scanRef="${INPUT_SCAN_REF:-.}"
if [ -n "${INPUT_IMAGE_REF:-}" ]; then
  scanRef="${INPUT_IMAGE_REF}" # backwards compatibility
fi

# Handle trivy ignores
if [ -n "${INPUT_TRIVYIGNORES:-}" ]; then
  ignorefile="./trivyignores"

  # Clear the ignore file if it exists, or create a new empty file
  : > "$ignorefile"

  for f in ${INPUT_TRIVYIGNORES//,/ }; do
    if [ -f "$f" ]; then
      echo "Found ignorefile '${f}':"
      cat "${f}"
      cat "${f}" >> "$ignorefile"
    else
      echo "ERROR: cannot find ignorefile '${f}'." >&2
      exit 1
    fi
  done
  export TRIVY_IGNOREFILE="$ignorefile"
fi

# Handle SARIF
if [ "${TRIVY_FORMAT:-}" = "sarif" ]; then
  if [ "${INPUT_LIMIT_SEVERITIES_FOR_SARIF:-false,,}" != "true" ]; then
    echo "Building SARIF report with all severities"
    unset TRIVY_SEVERITY
  else
    echo "Building SARIF report"
  fi
fi

# Run Trivy
cmd=(trivy "$scanType" "$scanRef")
echo "Running Trivy with options: ${cmd[*]}"
"${cmd[@]}"
returnCode=$?

if [ "${TRIVY_FORMAT:-}" = "github" ]; then
  if [ -n "${INPUT_GITHUB_PAT:-}" ]; then
    printf "\n Uploading GitHub Dependency Snapshot"
    curl -H 'Accept: application/vnd.github+json' -H "Authorization: token ${INPUT_GITHUB_PAT}" \
         "https://api.github.com/repos/$GITHUB_REPOSITORY/dependency-graph/snapshots" -d @"${TRIVY_OUTPUT:-}"
  else
    printf "\n Failing GitHub Dependency Snapshot. Missing github-pat" >&2
  fi
fi

exit $returnCode
