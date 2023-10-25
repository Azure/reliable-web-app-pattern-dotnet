GitHub Action Workflow uses this

https://github.com/Azure/get-keyvault-secrets

Find VMs
az vm list-skus --location westus2 --resource-type virtualMachines --zone --output table | grep -E "1,2,3|1,3,2|2,1,3|2,3,1|3,1,2|3,2,1"