#!/bin/sh -l
set -e
printenv
export INPUT_IMAGE_REF=${INPUT_IMAGE-REF}
echo "env var1 is" $(sh -c 'echo $INPUT_IMAGE-REF')
if [[ ${INPUT_SCAN-REF} ]]; then
  export INPUT_IMAGE_REF=$(sh -c 'echo $INPUT_SCAN-REF')
fi
echo "env var is" ${INPUT_IMAGE_REF}
exec trivy ${INPUT_SCAN-TYPE} --format=${INPUT_FORMAT} --template=${INPUT_TEMPLATE} --exit-code=${INPUT_EXIT-CODE} --ignore-unfixed=${INPUT_IGNORE-UNFIXED} --severity=${INPUT_SEVERITY} --output=${INPUT_OUTPUT} ${INPUT_IMAGE_REF}