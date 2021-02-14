#!/bin/bash
set -e
while getopts "a:b:c:d:e:f:g:h:i:j:" o; do
   case "${o}" in
       a)
         export scanType=${OPTARG}
       ;;
       b)
         export format=${OPTARG}
       ;;
       c)
         export template=${OPTARG}
       ;;
       d)
         export exitCode=${OPTARG}
       ;;
       e)
         export ignoreUnfixed=${OPTARG}
       ;;
       f)
         export vulnType=${OPTARG}
       ;;
       g)
         export severity=${OPTARG}
       ;;
       h)
         export output=${OPTARG}
       ;;
       i)
         export imageRef=${OPTARG}
       ;;
       j)
         export scanRef=${OPTARG}
       ;;
  esac
done

if [ $scanRef ];then
  imageRef=$scanRef
fi

if [ $ignoreUnfixed == "true" ];then
  trivy ${scanType} \
    --format ${format} \
    --template ${template} \
    --exit-code ${exitCode} \
    --ignore-unfixed \
    --vuln-type ${vulnType} \
    --severity ${severity} \
    --output ${output} \
    ${imageRef}
else
  trivy ${scanType} \
    --format ${format} \
    --template ${template} \
    --exit-code ${exitCode} \
    --vuln-type ${vulnType} \
    --severity ${severity} \
    --output ${output} \
    ${imageRef}
fi
