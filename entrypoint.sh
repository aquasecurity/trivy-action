#!/usr/bin/env bash
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

# If comment-on-pr is enabled and no output file is set, use a temp file
# so we can read scan results for the PR comment.
# Note: if output is configured via trivy.yaml (not via the action input), TRIVY_OUTPUT
# will be empty here and a temp file is used. Set the 'output' action input explicitly
# when combining comment-on-pr with trivy-config.
trivy_comment_file=""
original_trivy_output="${TRIVY_OUTPUT:-}"
if [ "${INPUT_COMMENT_ON_PR:-false}" = "true" ]; then
  if [ -z "${TRIVY_OUTPUT:-}" ]; then
    trivy_comment_file=$(mktemp "${TMPDIR:-/tmp}/trivy-results-XXXXXX")
    export TRIVY_OUTPUT="$trivy_comment_file"
  else
    trivy_comment_file="${TRIVY_OUTPUT}"
  fi
fi

# Run Trivy
cmd=("$TRIVY_CMD" "$scanType" "$scanRef")
echo "Running Trivy with options: ${cmd[*]}"

if [ "${INPUT_COMMENT_ON_PR:-false}" = "true" ]; then
  # Capture exit code so we can still post the comment on failure
  "${cmd[@]}" && returnCode=0 || returnCode=$?
else
  "${cmd[@]}"
  returnCode=$?
fi

# If we redirected output to a temp file, print results to stdout
# so they still appear in the action logs
if [ -n "$trivy_comment_file" ] && [ -z "$original_trivy_output" ] && [ -f "$trivy_comment_file" ]; then
  cat "$trivy_comment_file"
fi

# Post PR comment
if [ "${INPUT_COMMENT_ON_PR:-false}" = "true" ]; then
  if [ -z "${INPUT_GITHUB_TOKEN:-}" ]; then
    echo "WARNING: comment-on-pr is enabled but GITHUB_TOKEN is not available. Skipping PR comment." >&2
  elif [ -z "${GITHUB_EVENT_PATH:-}" ]; then
    echo "WARNING: GITHUB_EVENT_PATH is not set. Skipping PR comment." >&2
  else
    # Extract PR number from the event payload across all trigger types:
    #   pull_request / pull_request_target  → .pull_request.number
    #   workflow_run                        → .workflow_run.pull_requests[0].number
    #   issue_comment (on a PR only)        → .issue.number (guarded by .issue.pull_request)
    pr_number=$(jq -r '
      .pull_request.number //
      .workflow_run.pull_requests[0].number //
      (select(.issue.pull_request) | .issue.number) //
      empty
    ' "$GITHUB_EVENT_PATH" 2>/dev/null || true)

    if [ -z "$pr_number" ]; then
      echo "INFO: No associated pull request found. Skipping PR comment."
    else
      echo "Posting scan results as PR comment..."

      # Read scan results
      scan_results=""
      if [ -n "$trivy_comment_file" ] && [ -f "$trivy_comment_file" ]; then
        scan_results=$(cat "$trivy_comment_file")
      fi

      # If scan failed, always show the failure regardless of file contents
      # (the file may contain stale data from a previous scan in the same job)
      if [ "$returnCode" -ne 0 ] && [ -z "$scan_results" ]; then
        scan_results="Trivy scan failed with exit code ${returnCode}. Check the action logs for details."
      elif [ "$returnCode" -ne 0 ]; then
        scan_results="Trivy scan failed with exit code ${returnCode}.

${scan_results}"
      elif [ -z "$scan_results" ]; then
        scan_results="No vulnerabilities found."
      fi

      # Truncate if too long (GitHub comment limit is 65536 chars, leave room for markdown wrapper)
      max_len=60000
      if [ "${#scan_results}" -gt "$max_len" ]; then
        scan_results="${scan_results:0:$max_len}

... (truncated, full results available in the action logs)"
      fi

      # Determine code fence language based on format
      fence_lang=""
      case "${TRIVY_FORMAT:-table}" in
        json|sarif|github) fence_lang="json" ;;
      esac

      # Include scan type and target hash in marker so each unique scan
      # gets its own comment (e.g. two different image scans won't overwrite each other)
      # Also include TRIVY_INPUT for tarball scans where scanRef stays at default
      marker_input="${TRIVY_INPUT:-}"
      marker_hash=$(printf '%s:%s:%s' "$scanType" "$scanRef" "$marker_input" | cksum | cut -d' ' -f1)
      comment_marker="<!-- trivy-action-comment:${scanType}:${marker_hash} -->"

      # Show scan status in the header
      if [ "$returnCode" -ne 0 ]; then
        status_badge="**Status:** FAILED (exit code ${returnCode})"
      else
        status_badge="**Status:** Completed"
      fi

      comment_body="${comment_marker}
## Trivy Scan Results

**Scan type:** \`${scanType}\` | **Target:** \`${scanRef}\` | ${status_badge}

<details>
<summary>Click to expand scan results</summary>

\`\`\`${fence_lang}
${scan_results}
\`\`\`

</details>"

      # Escape for JSON payload
      comment_json=$(jq -n --arg body "$comment_body" '{"body": $body}')

      api_base="${GITHUB_API_URL:-https://api.github.com}"
      api_url="${api_base}/repos/${GITHUB_REPOSITORY}/issues/${pr_number}/comments"

      # Post or update PR comment
      # Disable exit-on-error so API failures don't abort a successful scan
      set +e

      # Search for existing trivy comment to update (avoids duplicate comments)
      # Paginate to handle PRs with many comments
      existing_comment_id=""
      page=1
      while [ -z "$existing_comment_id" ] && [ "$page" -le 5 ]; do
        page_comments=$(curl -s \
          -H "Authorization: token ${INPUT_GITHUB_TOKEN}" \
          -H "Accept: application/vnd.github+json" \
          "${api_url}?per_page=100&page=${page}")

        # Stop if page is empty
        if [ "$(echo "$page_comments" | jq 'length' 2>/dev/null)" = "0" ]; then
          break
        fi

        existing_comment_id=$(echo "$page_comments" \
          | jq --arg marker "$comment_marker" \
            '[.[] | select(.body | contains($marker))] | first | .id // empty' \
          2>/dev/null)
        page=$((page + 1))
      done

      if [ -n "$existing_comment_id" ]; then
        # Update existing comment
        http_code=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH \
          -H "Authorization: token ${INPUT_GITHUB_TOKEN}" \
          -H "Accept: application/vnd.github+json" \
          "${api_base}/repos/${GITHUB_REPOSITORY}/issues/comments/${existing_comment_id}" \
          -d "$comment_json")
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
          echo "Updated existing PR comment (comment ID: ${existing_comment_id})."
        else
          echo "WARNING: Failed to update PR comment (HTTP ${http_code}). Check token permissions (pull-requests: write)." >&2
        fi
      else
        # Create new comment
        http_code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
          -H "Authorization: token ${INPUT_GITHUB_TOKEN}" \
          -H "Accept: application/vnd.github+json" \
          "${api_url}" \
          -d "$comment_json")
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
          echo "Created new PR comment."
        else
          echo "WARNING: Failed to create PR comment (HTTP ${http_code}). Check token permissions (pull-requests: write)." >&2
        fi
      fi

      set -e
    fi
  fi

fi

if [ "${TRIVY_FORMAT:-}" = "github" ]; then
  if [ -n "${INPUT_GITHUB_PAT:-}" ]; then
    printf "\n Uploading GitHub Dependency Snapshot"
    curl -H 'Accept: application/vnd.github+json' -H "Authorization: token ${INPUT_GITHUB_PAT}" \
         "https://api.github.com/repos/$GITHUB_REPOSITORY/dependency-graph/snapshots" -d @"${TRIVY_OUTPUT:-}"
  else
    printf "\n Failing GitHub Dependency Snapshot. Missing github-pat" >&2
  fi
fi

# Cleanup temp file if we created one for PR commenting
if [ -n "${trivy_comment_file:-}" ] && [ -z "$original_trivy_output" ]; then
  rm -f "$trivy_comment_file"
fi

exit $returnCode
