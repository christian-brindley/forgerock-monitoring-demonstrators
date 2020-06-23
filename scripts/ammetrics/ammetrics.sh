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
# ammetrics.sh
# v1.beta - experimental
#
# Get metrics from AM
#
# Usage: ammetrics.sh propertiesfile
#



# getAmSession amurl userid password
# 
# Get AM session token
#

function getAmSession() {
    amurl=$1
    userid=$2
    password=$3

    json=`curl -k -s -X POST -H "X-OpenAM-Username: $userid" -H "X-OpenAM-Password: $password" -H "Content-Type: application/json" -H "Accept-API-Version: resource=2.1" $amurl/json/realms/root/authenticate`

    ssotoken=$(getJsonValue "$json" "tokenId")

    echo $ssotoken
}

# getSsoTokenHeader amurl
#
# Get the SSO token header name
#

function getSsoTokenHeader() {
    json=`curl -k -s -X GET $1/json/serverinfo/*`
    header=$(getJsonValue "$json" "cookieName")
    echo $header 
}

# getJsonValue json key
# 
# Extract value by key from json string (for systems without jq)
#

function getJsonValue() {
    value=`echo $1 | sed "s/^.*\"$2\": *\"//g" | sed s/\".*//`
    echo $value
}

function usage () {
  echo Usage: ammetrics propertiesfile
}

# getMetrics amurl userid password metrics
# 
# Get AM metrics
#

function getMetrics() {
    amurl=$1
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

    tokenheader=$(getSsoTokenHeader $amurl)
    ssotoken=$(getAmSession $amurl $userid $password)

    json=$( curl -k -s -H "${tokenheader}:${ssotoken}" -H "accept: application/json" -H "Accept-API-Version: resource=1.0,protocol=1.0" -H "Content-Type: application/json" "${amurl}/json/metrics/api?_queryFilter=$filter" )

    echo $json 
}


# getPrometheusMetrics amurl userid password fields
# 
# Get AM metrics via Prometheus endpoint
# 

function getPrometheusMetrics() { 
    amurl=$1 
    userid=$2 
    password=$3
    metrics=$4

    start=true

    filter=$( echo $metrics | sed "s/\ /\\\|/g" )
    echo -n "{"
    curl -k -s --user "$userid:$password"  "${amurl}/json/metrics/prometheus" | grep -v "^#" | grep $filter  | while read metric
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

# Go

if [[ $# != 1 ]]
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

if [ "$METHOD" == "prometheus" ]
then
    metrics=$( getPrometheusMetrics "$AM_BASE_URL" "$AM_USERNAME" "$AM_PASSWORD" "$PROM_METRICS" )
else
    metrics=$( getMetrics "$AM_BASE_URL" "$AM_USERNAME" "$AM_PASSWORD" "$API_METRICS" ) 
fi

timestamp=$( date -u +%Y-%m-%dT%H:%M:%SZ )
metrics=$( echo "{ \"timestamp\" : \"$timestamp\", \"metrics\" : " `echo "$metrics" | sed ':a;N;$!ba;s/\n/ /g'` "}" )
echo "$metrics"
