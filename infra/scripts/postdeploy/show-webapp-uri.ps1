
# The AZD deploy command shows the links to the azurewebsites.net resources
# We block access to these resources and instead want to show the Azure Front Door URL

Write-Host "Use this URI to access the web app:"
Write-Host (azd env get-values --output json | ConvertFrom-Json).WEB_URI