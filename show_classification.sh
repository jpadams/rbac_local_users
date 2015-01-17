#!/bin/bash

# simple 3.7 NC classifier commands

declare -x PE_CERT=$(/opt/puppet/bin/puppet agent --configprint hostcert)
declare -x PE_KEY=$(/opt/puppet/bin/puppet agent --configprint hostprivkey)
declare -x PE_CA=$(/opt/puppet/bin/puppet agent --configprint localcacert)

declare -x NC_CURL_OPT="-s --cacert $PE_CA --cert $PE_CERT --key $PE_KEY --insecure"

find_guid()
{
  echo $(curl $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/groups| python -m json.tool |grep -C 2 "$1" | grep "id" | cut -d: -f2 | sed 's/[\", ]//g')
}

show_classification()
{
  curl $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/groups/$1| python -m json.tool
}

show_classification `find_guid "$1"`

