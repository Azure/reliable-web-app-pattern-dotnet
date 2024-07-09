#!/bin/bash

# This script approves pending private endpoint connections for Azure Web Apps.
# It retrieves the resource group name from the environment variable $ResourceGroupName.
# It then lists all the web apps in the specified resource group and retrieves their IDs.
# For each web app, it checks for pending private endpoint connections and approves them.
# The approval is done by calling the 'az network private-endpoint-connection approve' command.
# The description for the approval is set to "ApprovedByCli".
#
# Usage: ./front-door-route-approval.sh
#
# Prerequisites:
# - Azure CLI must be installed and logged in.
# - The environment variable $ResourceGroupName must be set to the desired resource group name.
#
# Note: This script requires appropriate permissions to approve private endpoint connections.

rg_name="$ResourceGroupName"
if [[ -z "$rg_name" ]]; then
    echo "Resource group name not set. Please set the environment variable \$ResourceGroupName"
    exit 1
fi

# find all of the web apps (except the python one)
webapp_ids=$(az webapp list -g $rg_name --query '[? !contains(name, `py`)].id' | jq -r '.[]')

# Validate that we found a front-end and back-end web app.
# When deploying multi-region, we expect to find 2 web apps as two resource groups are deployed.
if [[ $(echo "$webapp_ids" | wc -w) -ne 2 ]]; then
    echo "Invalid webapp_ids length. Expected 2, but found $(echo "$webapp_ids" | wc -w)"
    exit 1
else
    echo "Proceeding to approve private endpoint connections for web apps in resource group: $rg_name"
fi

for webapp_id in $webapp_ids; do
    retry_count=0
    echo "Approving private endpoint connections for web app with ID: !!$webapp_id!!"

    # Retrieve the pending private endpoint connections for the web app.
    # The front door pending private endpoint connections will be created asynchronously
    # so the retry has been added for this scenario to await the asynchronous operation.
    while [[ $retry_count -lt 5 ]]; do
        fd_approved_conn_ids=$(az network private-endpoint-connection list --id "$webapp_id" --query "[?properties.provisioningState == 'Succeeded'].id" -o tsv)
        # break from loop if we found 2 approved private endpoint connections
        # because that means there is nothing to approve
        if [[ $(echo "$fd_approved_conn_ids" | wc -w) -eq 2 ]]; then
            echo "Found 2 approved private endpoint connections for web app with ID: $webapp_id"
            fd_conn_ids=""
            break
        fi

        fd_conn_ids=$(az network private-endpoint-connection list --id "$webapp_id" --query "[?properties.provisioningState == 'Pending'].id" -o tsv)
        # break from loop if we found any pending private endpoint connections
        if [[ $(echo "$fd_conn_ids" | wc -w) -gt 0 ]]; then
            break
        fi

        retry_count=$((retry_count + 1))
        # allows for a maximum of 30 seconds waiting with an incrementally increasing sleep duration
        sleep_duration=$((retry_count * 2))
        echo "... retrying in $sleep_duration seconds"
        sleep $sleep_duration
    done

    # report an error condition; we expect to find 2 approved private endpoint connections or to have something that needs approved
    if [[ $retry_count -eq 5 ]]; then
        echo "Failed to find pending private endpoint connections for web app with ID: $webapp_id"
        exit 1
    fi

    # Approve any pending private endpoint connections.
    for fd_conn_id in $fd_conn_ids; do
        echo "Approved private endpoint connection with ID: $fd_conn_id"
        az network private-endpoint-connection approve --id "$fd_conn_id" --description "ApprovedByCli"        
    done
done
