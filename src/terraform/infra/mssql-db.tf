resource "azurerm_mssql_database" "main" {

  name           = "sqldb-${var.application_name}-${var.environment_name}"
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 500
  read_scale     = true
  sku_name       = "P1"
  zone_redundant = true

}

resource "azurerm_resource_deployment_script_azure_power_shell" "createSqlUserScript" {
  name                = "createSqlUserScript"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  version             = "7.4"
  retention_interval  = "P1D"
  cleanup_preference  = "OnSuccess"
  force_update_tag    = random_uuid.always.result
  command_line        = " -ServerName '${azurerm_mssql_server.main.name}' -ResourceGroupName '${azurerm_resource_group.main.name}' -ServerUri '${azurerm_mssql_server.main.fully_qualified_domain_name}' -CatalogName '${azurerm_mssql_database.main.name}' -ApplicationId '${azurerm_user_assigned_identity.cluster_kubelet.principal_id}' -ManagedIdentityName '${azurerm_user_assigned_identity.cluster_kubelet.name}' -SqlAdminLogin '${var.sqldb_admin_username}' -SqlAdminPwd '${random_password.sqldb.result}' -IsProd 1"
  script_content      = file("../../scripts/deploymentScripts/createSqlAcctForManagedIdentity.ps1")

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.devops.id
    ]
  }

  depends_on = [azurerm_role_assignment.devops_contributor]
}