#!/bin/bash

#
# Config
#

AM_ADMIN_USERNAME="amadmin"
AM_ADMIN_PASSWORD="Passw0rd"
AM_URL="https://am.authdemo.org"

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

# recordCtl amUrl userid password { start [options] | stop | status }
#
# Start, stop or check recording
#

function recordCtl() {
    amUrl=$1
    userid=$2
    password=$3
    action=$4

    tokenheader=$(getSsoTokenHeader $amUrl)
    ssotoken=$(getAmSession $amUrl $userid $password)

    if [ $action == "start" ]
    then
        payload="$(getRecordPayload 111111 "problem" Passw0rd 60)"
    else
        payload=""
    fi

    curl -k -s -X POST "$amUrl/json/records?_action=$action" -H "${tokenheader}:${ssotoken}" -H "accept: application/json" --header "Accept-API-Version: resource=1.0,protocol=1.0" -H "Content-Type: application/json"  -d "$payload"
}


# getRecordPayload idnum idref 
# 
# Build JSON payload for records endpoint

function getRecordPayload () {

    id=$1
    ref=$2
    pass=$3
    time=$4

    payload="{ \
      \"issueID\": $id, \
      \"referenceID\": \"$ref\",  \
      \"description\": \"Troubleshooting artifacts\",  \
      \"zipEnable\": true,  \
      \"configExport\": {  \
        \"enable\": true,  \
        \"password\": \"Passw0rd\",  \
        \"sharePassword\": false  \
      },  \
      \"debugLogs\": {  \
        \"debugLevel\": \"MESSAGE\",  \
        \"autoStop\": {  \
          \"time\":  {  \
            \"timeUnit\": \"SECONDS\",  \
            \"value\": $time  \
          },  \
          \"fileSize\": {  \
            \"sizeUnit\": \"GB\",  \
            \"value\": 1  \
          }  \
       }  \
    },  \
    \"threadDump\" : {  \
      \"enable\": true,  \
      \"delay\" :  {  \
        \"timeUnit\": \"SECONDS\",  \
        \"value\": 5  \
      }  \
    }  \
  }"

  echo "$payload"
}

function usage () {
  echo Usage: amrecord.sh "{ start [options] | stop | status }"
}

# Go

if [ $# -eq 0 ]
then
    usage
    exit 1
fi

action=$1

if [ $action == "start" ]
then
    response=$(recordCtl $AM_URL $AM_ADMIN_USERNAME $AM_ADMIN_PASSWORD start)
    echo $(getJsonValue "$response" "status")
    exit 0
fi

if [ $action == "status" ]
then
    response=$(recordCtl $AM_URL $AM_ADMIN_USERNAME $AM_ADMIN_PASSWORD status)
    echo $response
    echo $(getJsonValue "$response" "recording")
    exit 0
fi

if [ $action == "stop" ]
then
    response=$(recordCtl $AM_URL $AM_ADMIN_USERNAME $AM_ADMIN_PASSWORD stop)
    echo $(getJsonValue "$response" "message")
    exit 0
fi

usage

