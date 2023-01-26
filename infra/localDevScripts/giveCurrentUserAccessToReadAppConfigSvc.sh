appConfigDataReaderRole='516239f1-63e1-4d78-a4de-a74fb236a071'
currentUserObjectId=$(az ad signed-in-user show --query "id" -o tsv)
scopeId=$(az group show -n "$myEnvironmentName-rg" --query "id" -o tsv)
az role assignment create --role $appConfigDataReaderRole --assignee ${currentUserObjectId:1:-2} --scope ${scopeId:1:-2}