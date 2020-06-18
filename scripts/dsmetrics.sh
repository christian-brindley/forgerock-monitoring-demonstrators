#!/bin/bash

#
# Config
#

MONITOR_USERNAME="monitor"
MONITOR_PASSWORD="Passw0rd"
DS_URL="https://userstore-1:18443"
DEFAULT_METRICS="\
disk./.free_space \
disk./.free_space_low_threshold \
disk./.free_space_full_threshold"

# getMetrics dsurl userid password [fields]
# 
# Get DS metrics
#

function getMetrics() {
    dsurl=$1
    filter=$2
    userid=$3
    password=$4
    fields=$5

    json=$(curl -k -s --user "$userid:$password"  "${dsurl}/metrics/api?_queryFilter=$filter")

    echo $json
}

function usage () {
  echo "Usage: dsmetrics.sh { fields | -a | -d }"
}

# Go

if [ $# == 0 ]
then
    usage
    exit 1
fi


if [ "$1" == "-a" ]
then
    filter=true
else
    filter=""
    if [ $1 == "-d" ]
    then
        metrics="$DEFAULT_METRICS"
    else
        metrics="$@"
    fi
    echo Metrics: $metrics

    for metric in $metrics
    do
	    echo $metric
        if [ -n "$filter" ]
	then
	    filter="${filter}%20or%20"
	fi
        filter="${filter}_id%20eq%20%22${metric}%22"
    done
fi

metrics=$(getMetrics "$DS_URL" $filter "$MONITOR_USERNAME" "$MONITOR_PASSWORD") 

echo $metrics
