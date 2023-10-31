resource "random_password" "sqldb" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_mssql_server" "main" {
  name                         = "sql-${var.application_name}-${var.environment_name}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sqldb_admin_username
  administrator_login_password = random_password.sqldb.result
}

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

resource "azurerm_key_vault_secret" "sqldb_admin_username" {
  name         = "sqldb-admin-username"
  value        = var.sqldb_admin_username
  key_vault_id = azurerm_key_vault.main.id
}
resource "azurerm_key_vault_secret" "sqldb_admin_password" {
  name         = "sqldb-admin-password"
  value        = random_password.sqldb.result
  key_vault_id = azurerm_key_vault.main.id
}