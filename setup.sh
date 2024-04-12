#!/bin/env bash
set -o nounset
set -o errexit
set -o errtrace
set -o pipefail
IFS=$'\n\t'

[ ! -z "${base_image}" ] && true || false

sed 's/placeholder/'"${base_image}"'/' Dockerfile
