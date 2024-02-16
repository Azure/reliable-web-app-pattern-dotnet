
# The AZD deploy command shows the links to the azurewebsites.net resources
# We block access to these resources and instead want to show the Azure Front Door URL

# Prompt formatting features

$defaultColor = if ($Host.UI.SupportsVirtualTerminal) { "`e[0m" } else { "" }
$highlightColor = if ($Host.UI.SupportsVirtualTerminal) { "`e[36m" } else { "" }

# End of Prompt formatting features

Write-Host "`nUse this URI to access the web app:"
$azureFrontDoorUri=(azd env get-values --output json | ConvertFrom-Json).WEB_URI
Write-Host "`t$($highlightColor)$azureFrontDoorUri$($defaultColor)"