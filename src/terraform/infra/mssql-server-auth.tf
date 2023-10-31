resource "random_password" "sqldb" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
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