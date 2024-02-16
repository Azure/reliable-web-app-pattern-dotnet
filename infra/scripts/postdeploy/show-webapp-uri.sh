#!/bin/bash

# The AZD deploy command shows the links to the azurewebsites.net resources
# We block access to these resources and instead want to show the Azure Front Door URL

echo "Use this URI to access the web app:"
echo $(azd env get-values --output json | jq -r '.WEB_URI')