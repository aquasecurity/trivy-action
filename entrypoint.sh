#!/bin/bash
set -euo pipefail

# Allow overriding trivy binary via env
TRIVY_CMD="${TRIVY_CMD:-trivy}"

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

  yaml_count=0
  plain_count=0

  # Validate files and detect types
  for f in ${INPUT_TRIVYIGNORES//,/ }; do
    if [ ! -f "$f" ]; then
      echo "ERROR: cannot find ignorefile '${f}'." >&2
      exit 1
    fi

    case "$f" in
      *.yml|*.yaml) yaml_count=$((yaml_count + 1)) ;;
      *) plain_count=$((plain_count + 1)) ;;
    esac
  done

  # Mixed types are not allowed
  if [ "$yaml_count" -gt 0 ] && [ "$plain_count" -gt 0 ]; then
    echo "ERROR: Cannot mix YAML and plain trivy ignore files." >&2
    exit 1
  fi

  # YAML mode
  if [ "$yaml_count" -gt 0 ]; then
    if [ "$yaml_count" -gt 1 ]; then
      echo "ERROR: Multiple YAML ignore files provided. Only one YAML file is supported." >&2
      exit 1
    fi

    # Use the single YAML file
    yaml_file=$(echo ${INPUT_TRIVYIGNORES//,/ } | awk '{print $1}')
    echo "Using YAML ignorefile '$yaml_file':"
    cat "$yaml_file"
    export TRIVY_IGNOREFILE="$yaml_file"

  else
    # Plain mode (old behaviour)
    ignorefile="./trivyignores"
    : > "$ignorefile"

    for f in ${INPUT_TRIVYIGNORES//,/ }; do
      echo "Found ignorefile '$f':"
      cat "$f"
      cat "$f" >> "$ignorefile"
    done

    export TRIVY_IGNOREFILE="$ignorefile"
  fi
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
cmd=("$TRIVY_CMD" "$scanType" "$scanRef")
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
