# this script handles soft deletes for Cognitive services

#$subscriptionId=(az account show --query id --output tsv)
# az rest --method get --header 'Accept=application/json' -u "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.CognitiveServices/deletedAccounts?api-version=2021-04-30"

# take the IDs and run 
# az resource delete --ids ''

# find soft deleted Key Vaults
az keyvault list-deleted

# take the names and run
az keyvault purge --name

# handle soft deleted App Config Svcs
az appconfig list-deleted

