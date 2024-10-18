#!/bin/bash
set -euo pipefail

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

# Ignore TRIVY_EXIT_CODE until formulation of action's output is finalized
export inputExitCode="$TRIVY_EXIT_CODE"
export TRIVY_EXIT_CODE=1

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

# return an output based on result whilst honoring exit-code input
case $inputExitCode$returnCode in
  00)
    echo "result=pass" >> "$GITHUB_OUTPUT" # No findings
    exit 0
    ;;
  10)
    echo "result=pass" >> "$GITHUB_OUTPUT" # No findings
    exit 0
    ;;
  01)
    echo "result=fail" >> "$GITHUB_OUTPUT" # Findings present but TRIVY_EXIT_CODE=0 
    exit 0
    ;;
  11)
    echo "result=fail" >> "$GITHUB_OUTPUT" # Findings present and TRIVY_EXIT_CODE=1
    exit 1
    ;;
esac
