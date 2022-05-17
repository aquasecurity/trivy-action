#!/bin/bash
set -e
while getopts "a:b:c:d:e:f:g:h:i:j:k:l:m:n:o:p:q:r:s:" o; do
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
         export imageRefs=${OPTARG}
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
         export securityChecks=${OPTARG}
       ;;
  esac
done

scanType=$(echo $scanType | tr -d '\r')
export artifactsRefs="${imageRefs}"
if [ "${scanType}" = "repo" ] || [ "${scanType}" = "fs" ] ||  [ "${scanType}" = "config" ] ||  [ "${scanType}" = "rootfs" ];then
  artifactRef=$(echo $scanRef | tr -d '\r')
fi
input=$(echo $input | tr -d '\r')
if [ $input ]; then
  artifactRef="--input $input"
fi
ignoreUnfixed=$(echo $ignoreUnfixed | tr -d '\r')
hideProgress=$(echo $hideProgress | tr -d '\r')

GLOBAL_ARGS=""
if [ $cacheDir ];then
  GLOBAL_ARGS="$GLOBAL_ARGS --cache-dir $cacheDir"
fi

SARIF_ARGS=""
ARGS=""
if [ $format ];then
 ARGS="$ARGS --format $format"
fi
if [ $template ] ;then
 ARGS="$ARGS --template $template"
fi
if [ $exitCode ];then
 ARGS="$ARGS --exit-code $exitCode"
fi
if [ "$ignoreUnfixed" == "true" ] && [ "$scanType" != "config" ];then
  ARGS="$ARGS --ignore-unfixed"
  SARIF_ARGS="$SARIF_ARGS --ignore-unfixed"
fi
if [ $vulnType ] && [ "$scanType" != "config" ];then
  ARGS="$ARGS --vuln-type $vulnType"
  SARIF_ARGS="$SARIF_ARGS --vuln-type $vulnType"
fi
if [ $securityChecks ] && [ "$scanType" == "fs" ];then
  ARGS="$ARGS --security-checks $securityChecks"
fi
if [ $securityChecks ] && [ "$scanType" == "repo" ];then
  ARGS="$ARGS --security-checks $securityChecks"
fi
if [ $severity ];then
  ARGS="$ARGS --severity $severity"
fi
if [ $skipDirs ];then
  for i in $(echo $skipDirs | tr "," "\n")
  do
    ARGS="$ARGS --skip-dirs $i"
    SARIF_ARGS="$SARIF_ARGS --skip-dirs $i"
  done
fi
if [ $timeout ];then
  ARGS="$ARGS --timeout $timeout"
fi
if [ $ignorePolicy ];then
  ARGS="$ARGS --ignore-policy $ignorePolicy"
  SARIF_ARGS="$SARIF_ARGS --ignore-policy $ignorePolicy"
fi
if [ "$hideProgress" == "true" ];then
  ARGS="$ARGS --no-progress"
fi

listAllPkgs=$(echo $listAllPkgs | tr -d '\r')
if [ "$listAllPkgs" == "true" ];then
  ARGS="$ARGS --list-all-pkgs"
fi
if [ "$skipFiles" ];then
  for i in $(echo $skipFiles | tr "," "\n")
  do
    ARGS="$ARGS --skip-files $i"
  done
fi
echo "Running trivy with options: ${ARGS}" "${artifactsRefs}"
echo "Global options: " "${GLOBAL_ARGS}"
for artifactRef in ${artifactsRefs//,/$IFS}; do
  echo "Scanning $artifactRef"
  if [ $output ];then
    ARGS1="$ARGS --output $( echo ${artifactRef//\:/-} | cut -d '/' -f2- | sed 's/\//-/g')-${output// /}"
  fi
  trivy $GLOBAL_ARGS ${scanType} $ARGS1 ${artifactRef} 
  eCode=$?
  if [[ $eCode -gt 0 ]]; then
    export returnCode=$eCode
  fi

  # SARIF is special. We output all vulnerabilities,
  # regardless of severity level specified in this report.
  # This is a feature, not a bug :)
  format="$(echo $format)"
  if [[ "${format}" == "sarif" ]]; then
    echo "Building SARIF report with options: ${SARIF_ARGS}" "${artifactRef}"
    trivy --quiet ${scanType} --format sarif --output $( echo ${artifactRef//\:/-} | cut -d '/' -f2- | sed 's/\//-/g')-${output// /} $SARIF_ARGS ${artifactRef}
  fi
done
exit $returnCode
