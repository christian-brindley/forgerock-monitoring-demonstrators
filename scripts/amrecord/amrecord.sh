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
# amrecord.sh
# v1.beta - experimental
#
# Manage AM recordings for debugging
#
# Usage: amrecord.sh propertiesfile { start | stop | status }
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

# recordCtl amUrl userid password { start | stop | status } options
#
# Start, stop or check recording
#

function recordCtl() {
    action=$1
    amUrl=$2
    userid=$3
    password=$4
    id=$5
    desc=$6
    duration=$7
    zippass=$8
    
    tokenheader=$(getSsoTokenHeader $amUrl)
    ssotoken=$(getAmSession $amUrl $userid $password)

    if [ $action == "start" ]
    then
        payload=$(getRecordPayload "$id" "$desc" "$zippass" "$duration")
    else
        payload=""
    fi

    curl -k -s -X POST "$amUrl/json/records?_action=$action" -H "${tokenheader}:${ssotoken}" -H "accept: application/json" --header "Accept-API-Version: resource=1.0,protocol=1.0" -H "Content-Type: application/json"  -d "$payload"
}


# getRecordPayload id description zippass duration
# 
# Build JSON payload for records endpoint

function getRecordPayload () {

    id=$1
    desc=$2
    zippass=$3
    time=$4

    payload="{ \
      \"issueID\": $id, \
      \"referenceID\": \"$id\",  \
      \"description\": \"$desc\",  \
      \"zipEnable\": true,  \
      \"configExport\": {  \
        \"enable\": true,  \
        \"password\": \"$zippass\",  \
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
        \"value\": $time  \
      }  \
    }  \
  }"

  echo "$payload"
}

function usage () {
  echo Usage: amrecord.sh "propertiesfile { start | stop | status }"
}

# Go

if [[ $# != 2 ]]
then
    usage
    exit 1
fi

propertiesfile=$1
action=$2

if [ ! -f $propertiesfile ]
then
    echo "Properties file $propertiesfile does not exist"
    exit 1
fi

. $propertiesfile


if [ $action == "start" ]
then
    response=$(recordCtl start $AM_URL $AM_ADMIN_USERNAME $AM_ADMIN_PASSWORD "$RECORDING_ID" "$RECORDING_DESCRIPTION" "$RECORDING_DURATION" "$ZIP_PASSWORD" )
    echo $response
    exit 0
fi

if [ $action == "status" ]
then
    response=$(recordCtl status $AM_URL $AM_ADMIN_USERNAME $AM_ADMIN_PASSWORD)
    echo $response
    exit 0
fi

if [ $action == "stop" ]
then
    response=$(recordCtl stop $AM_URL $AM_ADMIN_USERNAME $AM_ADMIN_PASSWORD)
    echo $response
    exit 0
fi

usage
