#!/bin/bash
set -e
while getopts "a:b:c:d:e:f:g:h:i:j:k:l:m:n:o:" o; do
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
  esac
done

scanType=$(echo $scanType | tr -d '\r')
export artifactRef="${imageRef}"
if [ "${scanType}" = "fs" ];then
  artifactRef=$(echo $scanRef | tr -d '\r')
fi
input=$(echo $input | tr -d '\r')
if [ $input ]; then
  artifactRef="--input $input"
fi
ignoreUnfixed=$(echo $ignoreUnfixed | tr -d '\r')

GLOBAL_ARGS=""
if [ $cacheDir ];then
  GLOBAL_ARGS="$GLOBAL_ARGS --cache-dir $cacheDir"
fi

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
if [ "$ignoreUnfixed" == "true" ] && ["$vulnType" != "config"];then
  ARGS="$ARGS --ignore-unfixed"
fi
if [ $vulnType ] && ["$vulnType" != "config"];then
  ARGS="$ARGS --vuln-type $vulnType"
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
  done
fi
if [ $timeout ];then
  ARGS="$ARGS --timeout $timeout"
fi
if [ $ignorePolicy ];then
  ARGS="$ARGS --ignore-policy $ignorePolicy"
fi

echo "Running trivy with options: ${ARGS}" "${artifactRef}"
echo "Global options: " "${GLOBAL_ARGS}"
trivy $GLOBAL_ARGS ${scanType} $ARGS ${artifactRef}
