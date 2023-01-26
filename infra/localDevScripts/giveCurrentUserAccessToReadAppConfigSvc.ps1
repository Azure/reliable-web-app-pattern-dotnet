$appConfigDataReaderRole='516239f1-63e1-4d78-a4de-a74fb236a071'
$currentUserObjectId=(az ad signed-in-user show --query "id")
$scopeId=(az group show -n "$myEnvironmentName-rg" --query "id")
az role assignment create --role $appConfigDataReaderRole --assignee $currentUserObjectId --scope $scopeId