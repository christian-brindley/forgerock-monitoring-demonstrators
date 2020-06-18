#!/bin/bash

# getMetrics dsurl userid password [fields]
# 
# Get DS metrics
#

function getMetrics() {
    dsurl=$1
    userid=$2
    password=$3
    metrics=$4

    filter=""

    for metric in $metrics
    do
        if [ -n "$filter" ]
	then
	    filter="${filter}%20or%20"
	fi
        filter="${filter}_id%20eq%20%22${metric}%22"
    done

    json=$(curl -k -s --user "$userid:$password"  "${dsurl}/metrics/api?_queryFilter=$filter")

    echo $json
}


# getPrometheusMetrics dsurl userid password [fields]
# 
# Get DS metrics via Prometheus endpoint
#

function getPrometheusMetrics() {
    dsurl=$1
    userid=$2
    password=$3
    metrics=$4

    filter=$( echo $metrics | sed "s/\ /\\\|/g" )
    curl -k -s --user "$userid:$password"  "${dsurl}/metrics/prometheus" | grep -v "^#" | grep $filter
}


function usage () {
    echo "Usage: dsmetrics.sh propertiesfile"
}

function log () {
    logfile=$LOG_FILE_BASE.`date -u +%Y-%m-%d`
    timestamp=$( date -u +%Y-%m-%dT%H:%M:%SZ )
    echo "{ \"timestamp\" : \"$timestamp\", \"metrics\" : $1 }" >> $logfile
}

# Go

if [ $# != 1 ]
then
    usage
    exit 1
fi

propertiesfile=$1

. $propertiesfile

if [ "$METHOD" == "prometheus" ]
then
    metrics=$( getPrometheusMetrics "$DS_BASE_URL" "$MONITOR_USERNAME" "$MONITOR_PASSWORD" "$PROM_METRICS" )
else
    metrics=$( getMetrics "$DS_BASE_URL" "$MONITOR_USERNAME" "$MONITOR_PASSWORD" "$API_METRICS" ) 
fi


log "$metrics"
