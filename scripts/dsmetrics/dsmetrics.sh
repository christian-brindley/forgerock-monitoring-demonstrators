#!/bin/bash

##############################################################################
# DISCLAIMER                                                                 #
#                                                                            #
# The sample code described herein is provided on an "as is" basis, without  #
# warranty of any kind, to the fullest extent permitted by law. ForgeRock    #
# does not warrant or guarantee the individual success developers may have   #
# in implementing the sample code on their development platforms or in       #
# production configurations. ForgeRock does not warrant, guarantee or make   #
# any representations regarding the use, results of use, accuracy,           #
# timeliness or completeness of any data or information relating to the      #
# sample code. ForgeRock disclaims all warranties, expressed or implied, and #
# in particular, disclaims all warranties of merchantability, and            #
# warranties related to the code, or any service or software related         #
# thereto.                                                                   #
#                                                                            #
# ForgeRock shall not be liable for any direct, indirect or consequential    #
# damages or costs of any type arising out of any action taken by you or     #
# others related to the sample code.                                         #
##############################################################################

#
# dsmetrics.sh
# v1.beta - experimental
#
# Get metrics from ForgeRock Directory Services 
# 
# Usage: dsmetrics.sh propertiesfile
#


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

    json=$(curl -k -s --user "$userid:$password"  "${dsurl}/metrics/api?_queryFilter=$filter"  2>>${LOG_FILE_BASE}.error)

    echo $json # | jq -c .result
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

    start=true

    filter=$( echo $metrics | sed "s/\ /\\\|/g" )
    echo -n "{"
    curl -k -s --user "$userid:$password"  "${dsurl}/metrics/prometheus"  2>>${LOG_FILE_BASE}.error | grep -v "^#" | grep $filter  | while read metric
    do
            if [ $start == "true" ]
            then
                start=false
            else
                echo ","
            fi
            echo "\"$(echo $metric | cut -d" " -f1)\" : $(echo $metric | cut -d" " -f2-)"
    done
    echo -n "}"

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

    echo -n "{"
    filter=$( echo $metrics | sed "s/\ /\\\|/g" )
    $LDAPSEARCH -D "$binddn" -w "$password" -h $dshost -p $dsport --baseDN "cn=monitor"  -Z  --trustAll  "(&)" 2>>${LOG_FILE_BASE}.error| grep $filter | while read metric
    do
            if [ $start == "true" ]
            then
                start=false
            else
                echo ","
            fi
            echo "\"$(echo $metric | cut -d":" -f1)\" : $(echo $metric | cut -d":" -f2-)"
    done
    echo -n "}"
}

# usage
# 
# display usage information
#
 
function usage () {
    echo "Usage: dsmetrics.sh propertiesfile"
}

# cleanlogs days
# 
# clean up log from x days ago
#

function cleanlogs () {
    days=$1

    oldlog=$LOG_FILE_BASE.`date -u --date "-${days} days" +%Y-%m-%d`
    if [ -f "$oldlog" ]
    then
        rm -f "$oldlog"
    fi
}

# log metrics
# 
# write message to log with timestamp and success indicator
#

function log () {
    metrics=$1

    if [ -z "$LOG_FILE_BASE" ]
    then
        echo "$metrics"
    else
        if [[ -n "$LOG_ROTATE" && "$LOG_ROTATE" != 0 ]]
        then
            cleanlogs $LOG_ROTATE
            logfile=$LOG_FILE_BASE.`date -u +%Y-%m-%d`
        else
            logfile=$LOG_FILE_BASE
        fi
     
        timestamp=$( date -u +%Y-%m-%dT%H:%M:%SZ )
        if [ -n "$metrics" ]
        then
            response=true
        else
            response=false
        fi
        echo "{ \"timestamp\" : \"$timestamp\", \"response\" : $response, \"metrics\" : $metrics }" >> $logfile
    fi
}

# checkconfig propertiesfile
#
# Check configuration
#

function checkconfig () {
    error=0

    [ -z "$MONITOR_PASSWORD" ] && echo "No value specified for MONITOR_PASSWORD" && error=1

    [ $error == 0 ]
}

# Go

if [ $# != 1 ]
then
    usage
    exit 1
fi

propertiesfile=$1

if [ ! -f $propertiesfile ]
then
    echo "Properties file $propertiesfile does not exist"
    exit 1
fi

. $propertiesfile

if ! checkconfig
then
    echo Error in config
    exit 1
fi


if [ "$METHOD" == "prometheus" ]
then
    metrics=$( getPrometheusMetrics "$DS_BASE_URL" "$MONITOR_USERNAME" "$MONITOR_PASSWORD" "$PROM_METRICS" )
elif [ "$METHOD" == "ldaps" ]
then
    metrics=$( getLdapMetrics "$DS_LDAP_HOST" "$DS_LDAP_PORT" "$MONITOR_BINDDN" "$MONITOR_PASSWORD" "$LDAP_METRICS" ) 
else
    metrics=$( getMetrics "$DS_BASE_URL" "$MONITOR_USERNAME" "$MONITOR_PASSWORD" "$API_METRICS" ) 
fi

metrics=$( echo "$metrics" | sed ':a;N;$!ba;s/\n/ /g' )
log "$metrics"
