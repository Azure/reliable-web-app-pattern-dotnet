#!/bin/bash

# The AZD deploy command shows the links to the azurewebsites.net resources
# We block access to these resources and instead want to show the Azure Front Door URL

pwsh ./infra/scripts/postdeploy/show-webapp-uri.ps1