#!/bin/bash
set -e
while getopts "a:b:c:d:e:f:g:h:i:j:k:l:" o; do
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
if [ "$ignoreUnfixed" == "true" ];then
  ARGS="$ARGS --ignore-unfixed"
fi
if [ $vulnType ];then
  ARGS="$ARGS --vuln-type $vulnType"
fi
if [ $severity ];then
  ARGS="$ARGS --severity $severity"
fi
if [ $output ];then
  ARGS="$ARGS --output $output"
fi
if [ $skipDirs ];then
  ARGS="$ARGS --skip-dirs $skipDirs"
fi

echo "Running trivy with options: " --no-progress "${ARGS}" "${artifactRef}"
trivy ${scanType} --no-progress $ARGS ${artifactRef}
