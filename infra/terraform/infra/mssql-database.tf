resource "azurerm_mssql_database" "application_database" {
  name           = "sqldb-${var.application_name}-${var.environment_name}"
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 500
  read_scale     = true
  sku_name       = "P1"
  zone_redundant = true
}

locals {
  create_sql_user_params = {
    ServerName          = azurerm_mssql_server.main.name
    ResourceGroupName   = azurerm_resource_group.main.name
    ServerUri           = azurerm_mssql_server.main.fully_qualified_domain_name
    CatalogName         = azurerm_mssql_database.application_database.name
    ApplicationId       = azurerm_user_assigned_identity.cluster_kubelet.principal_id
    ManagedIdentityName = azurerm_user_assigned_identity.cluster_kubelet.name
    SqlAdminLogin       = var.mssql_admin_username
    SqlAdminPwd         = random_password.mssql_server.result
    IsProd              = "1"
    # 'IsProd' is not a string, it should be a boolean, hence the replace function on the aggregated string
  }
  create_sql_user_formatted_params = replace(join(" ", [for k, v in local.create_sql_user_params : "-${k} '${v}'"]), "'1'", "1")
}

resource "azurerm_resource_deployment_script_azure_power_shell" "createSqlUserScript" {

  name                = "createSqlUserScript"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  version             = "7.4"
  retention_interval  = "P1D"
  command_line        = local.create_sql_user_formatted_params
  cleanup_preference  = "OnSuccess"
  force_update_tag    = random_uuid.always.result
  timeout             = "PT30M"

  script_content = file("../../scripts/deploymentScripts/createSqlAcctForManagedIdentity.ps1")

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.devops.id
    ]
  }

  depends_on = [
    azurerm_role_assignment.devops_contributor,
    azurerm_mssql_firewall_rule.allow_all
  ]
}
