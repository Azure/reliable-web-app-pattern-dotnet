#!/bin/sh

# This script will be run by the Azure Developer CLI.
#
# Retrieves the public IP address of the current system, as seen by Azure.  To do this, it
# uses ipinfo.io as an external service.  Afterwards, it sets the AZD_IP_ADDRESS environment
# variable and sets the `azd env set` command to set it within Azure Developer CLI as well.

echo '...make API call'
ipaddress=`curl -s https://ipinfo.io/ip`

# if $ipaddress is empty, exit with error
if [ -z "$ipaddress" ]; then
    echo '...no IP address returned'
    exit 1
fi

echo '...export'
export AZD_IP_ADDRESS=$ipaddress

echo '...set value'
azd env set AZD_IP_ADDRESS $ipaddress