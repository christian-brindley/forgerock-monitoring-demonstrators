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

    echo $json | jq -c .result
}


# getPrometheusMetrics dsurl userid password fields
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

# getLdapMetrics dshost dsport binddn password fields
# 
# Get DS metrics via LDAP
#

function getLdapMetrics() {
    dshost=$1
    dsport=$2
    binddn=$3
    password=$4
    metrics=$5

    start=true

    filter=$( echo $metrics | sed "s/\ /\\\|/g" )
    $LDAPSEARCH -D "$binddn" -w "$password" -h $dshost -p $dsport --baseDN "cn=monitor"  -Z  --trustAll  "(&)" | grep $filter | while read metric
    do
            if [ $start == "true" ]
            then
                echo "{"
                start=false
            else
                echo ","
            fi
            echo $metric | sed -E "s/(.*):(.*)/\"\1\" : \2/"
    done 
    echo "}"
}

function usage () {
    echo "Usage: dsmetrics.sh propertiesfile"
}

function log () {
    if [ -z "$LOG_FILE_BASE" ]
    then
        echo "$1"
    else
        logfile=$LOG_FILE_BASE.`date -u +%Y-%m-%d`
        timestamp=$( date -u +%Y-%m-%dT%H:%M:%SZ )
        echo "{ \"timestamp\" : \"$timestamp\", \"metrics\" : $1 }" >> $logfile
    fi
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
elif [ "$METHOD" == "ldaps" ]
then
    metrics=$( getLdapMetrics "$DS_LDAP_HOST" "$DS_LDAP_PORT" "$MONITOR_BINDDN" "$MONITOR_PASSWORD" "$LDAP_METRICS" ) 
else
    metrics=$( getMetrics "$DS_BASE_URL" "$MONITOR_USERNAME" "$MONITOR_PASSWORD" "$API_METRICS" ) 
fi


log "$metrics"
