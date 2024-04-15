#!/bin/bash
set -e
while getopts "a:b:c:d:e:f:g:h:i:j:k:l:m:n:o:p:q:r:s:t:u:v:x:y:z:" o; do
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
       k)
         export skipDirs=${OPTARG}
       ;;
       l)
         export input=${OPTARG}
       ;;
       m)
         export cacheDir=${OPTARG}
       ;;
       n)
         export timeout=${OPTARG}
       ;;
       o)
         export ignorePolicy=${OPTARG}
       ;;
       p)
         export hideProgress=${OPTARG}
       ;;
       q)
         export skipFiles=${OPTARG}
       ;;
       r)
         export listAllPkgs=${OPTARG}
       ;;
       s)
         export scanners=${OPTARG}
       ;;
       t)
         export trivyIgnores=${OPTARG}
       ;;
       u)
         export githubPAT=${OPTARG}
       ;;
       v)
         export trivyConfig=${OPTARG}
       ;;
       x)
         export tfVars=${OPTARG}
       ;;
       y)
         export dockerHost=${OPTARG}
       ;;
       z)
         export limitSeveritiesForSARIF=${OPTARG}
       ;;
  esac
done


scanType=$(echo $scanType | tr -d '\r')
export artifactRef="${imageRef}"
if [ "${scanType}" = "repo" ] || [ "${scanType}" = "fs" ] || [ "${scanType}" = "filesystem" ] ||  [ "${scanType}" = "config" ] ||  [ "${scanType}" = "rootfs" ] || [ "${scanType}" = "sbom" ];then
  artifactRef=$(echo $scanRef | tr -d '\r')
fi
input=$(echo $input | tr -d '\r')
if [ $input ]; then
  artifactRef="--input $input"
fi
#trim leading spaces for boolean params
ignoreUnfixed=$(echo $ignoreUnfixed | tr -d '\r')
hideProgress=$(echo $hideProgress | tr -d '\r')
limitSeveritiesForSARIF=$(echo $limitSeveritiesForSARIF | tr -d '\r')

GLOBAL_ARGS=""
if [ $cacheDir ];then
  GLOBAL_ARGS="$GLOBAL_ARGS --cache-dir $cacheDir"
fi

SARIF_ARGS=""
ARGS=""
format=$(echo $format | xargs)
if [ $format ];then
 ARGS="$ARGS --format $format"
fi
if [ $template ] ;then
 ARGS="$ARGS --template $template"
fi
if [ $exitCode ];then
 ARGS="$ARGS --exit-code $exitCode"
 SARIF_ARGS="$SARIF_ARGS --exit-code $exitCode"
fi
if [ "$ignoreUnfixed" == "true" ] && [ "$scanType" != "config" ];then
  ARGS="$ARGS --ignore-unfixed"
  SARIF_ARGS="$SARIF_ARGS --ignore-unfixed"
fi
if [ $vulnType ] && [ "$scanType" != "config" ] && [ "$scanType" != "sbom" ];then
  ARGS="$ARGS --vuln-type $vulnType"
  SARIF_ARGS="$SARIF_ARGS --vuln-type $vulnType"
fi
if [ $scanners ];then
  ARGS="$ARGS --scanners $scanners"
  SARIF_ARGS="$SARIF_ARGS --scanners $scanners"
fi
if [ $severity ];then
  ARGS="$ARGS --severity $severity"
fi
if [ $output ];then
  ARGS="$ARGS --output $output"
fi
if [ $skipDirs ];then
  for i in $(echo $skipDirs | tr "," "\n")
  do
    ARGS="$ARGS --skip-dirs $i"
    SARIF_ARGS="$SARIF_ARGS --skip-dirs $i"
  done
fi
if [ $tfVars ] && [ "$scanType" == "config" ];then
  ARGS="$ARGS --tf-vars $tfVars"
fi

if [ $trivyIgnores ];then
  for f in $(echo $trivyIgnores | tr "," "\n")
  do
    if [ -f "$f" ]; then
      echo "Found ignorefile '${f}':"
      cat "${f}"
      cat "${f}" >> ./trivyignores
    else
      echo "ERROR: cannot find ignorefile '${f}'."
      exit 1
    fi
  done
  ARGS="$ARGS --ignorefile ./trivyignores"
fi
if [ $timeout ];then
  ARGS="$ARGS --timeout $timeout"
  SARIF_ARGS="$SARIF_ARGS --timeout $timeout"
fi
if [ $ignorePolicy ];then
  ARGS="$ARGS --ignore-policy $ignorePolicy"
  SARIF_ARGS="$SARIF_ARGS --ignore-policy $ignorePolicy"
fi
if [ "$hideProgress" == "true" ];then
  ARGS="$ARGS --quiet"
  SARIF_ARGS="$SARIF_ARGS --quiet"
fi
if [ $dockerHost ];then
  ARGS="$ARGS --docker-host $dockerHost"
fi

listAllPkgs=$(echo $listAllPkgs | tr -d '\r')
if [ "$listAllPkgs" == "true" ];then
  ARGS="$ARGS --list-all-pkgs"
fi
if [ "$skipFiles" ];then
  for i in $(echo $skipFiles | tr "," "\n")
  do
    ARGS="$ARGS --skip-files $i"
    SARIF_ARGS="$SARIF_ARGS --skip-files $i"
  done
fi

trivyConfig=$(echo $trivyConfig | tr -d '\r')
# To make sure that uploda GitHub Dependency Snapshot succeeds, disable the script that fails first.
set +e
if [ "${format}" == "sarif" ] && [ "${limitSeveritiesForSARIF}" != "true" ]; then
  # SARIF is special. We output all vulnerabilities,
  # regardless of severity level specified in this report.
  # This is a feature, not a bug :)
  echo "Building SARIF report with options: ${SARIF_ARGS}" "${artifactRef}"
  trivy --quiet ${scanType} --format sarif --output ${output} $SARIF_ARGS ${artifactRef}
elif [ $trivyConfig ]; then
   echo "Running Trivy with trivy.yaml config from: " $trivyConfig
   trivy --config $trivyConfig ${scanType} ${artifactRef}
else
   echo "Running trivy with options: trivy ${scanType} ${ARGS}" "${artifactRef}"
   echo "Global options: " "${GLOBAL_ARGS}"
   trivy $GLOBAL_ARGS ${scanType} ${ARGS} ${artifactRef}
fi
returnCode=$?

set -e
if [[ "${format}" == "github" ]]; then
  if [[ "$(echo $githubPAT | xargs)" != "" ]]; then
    printf "\n Uploading GitHub Dependency Snapshot"
    curl -H 'Accept: application/vnd.github+json' -H "Authorization: token $githubPAT" 'https://api.github.com/repos/'$GITHUB_REPOSITORY'/dependency-graph/snapshots' -d @./$(echo $output | xargs)
  else
    printf "\n Failing GitHub Dependency Snapshot. Missing github-pat"
  fi
fi

exit $returnCode
