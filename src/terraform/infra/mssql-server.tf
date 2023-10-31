resource "azurerm_mssql_server" "main" {
  name                         = "sql-${var.application_name}-${var.environment_name}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sqldb_admin_username
  administrator_login_password = random_password.sqldb.result

  azuread_administrator {
    login_username = azurerm_user_assigned_identity.cluster_kubelet.name
    tenant_id      = azurerm_user_assigned_identity.cluster_kubelet.tenant_id
    object_id      = azurerm_user_assigned_identity.cluster_kubelet.principal_id
  }
}

resource "azurerm_mssql_firewall_rule" "sqldb" {
  name             = "AllowAllWindowsAzureIps"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_resource_deployment_script_azure_power_shell" "allowSqlAdminScript" {
  name                = "allowSqlAdminScript"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  version             = "7.4"
  retention_interval  = "P1D"
  cleanup_preference  = "OnSuccess"
  force_update_tag    = random_uuid.always.result
  command_line        = "-SqlServerName '${azurerm_mssql_server.main.name}' -ResourceGroupName '${azurerm_resource_group.main.name}'"
  script_content      = file("../../scripts/deploymentScripts/enableSqlAdminForServer.ps1")

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.devops.id
    ]
  }

  depends_on = [azurerm_role_assignment.devops_contributor]
}

resource "random_uuid" "always" {
  keepers = {
    first = "${timestamp()}"
  }
}
