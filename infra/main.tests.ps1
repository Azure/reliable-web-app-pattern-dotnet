﻿####################################################################################################
# Install prerequisites:
####################################################################################################
winget install -s winget -e --id "Microsoft.PowerShell"
winget install -s winget -e --id "Microsoft.Bicep"

Install-Module -Name 'Az' -Repository PSGallery -Force
Install-Module -Name 'PSRule.Rules.Azure' -Repository PSGallery -Scope CurrentUser

Set-Location .\infra\
# report summary of all PsRule.Rules.Azure checks
Invoke-PSRule -Format File -InputPath '*.tests.bicep' -Module 'PSRule.Rules.Azure' -Outcome Processed -As Summary

# report detail of all PsRule.Rules.Azure checks
Invoke-PSRule -Format File -InputPath '*.tests.bicep' -Module 'PSRule.Rules.Azure' -Outcome Fail, Error -As Detail

# report detail of all PsRule.Rules.Azure checks with formatting
Assert-PSRule -Format File -InputPath '*.tests.bicep' -Module 'PSRule.Rules.Azure' -Outcome Fail, Error

# Note: Invoke-PSRule and Assert-PSRule are the same except for the output format
# * Invoke-PSRule writes results as structured objects
# * Assert-PSRule writes results as a formatted string