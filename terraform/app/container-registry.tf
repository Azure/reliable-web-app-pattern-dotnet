resource "azurerm_container_registry" "main" {
  name                    = "acr-${var.application_name}-${var.environment_name}"
  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  sku                     = "Premium"
  admin_enabled           = true
  zone_redundancy_enabled = true
}

resource "azurerm_key_vault_secret" "acr_admin_username" {

  name         = "acr-admin-username"
  value        = azurerm_container_registry.main.admin_username
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.keyvault_terraform_user]

}

resource "azurerm_key_vault_secret" "acr_admin_password" {

  name         = "acr-admin-password"
  value        = azurerm_container_registry.main.admin_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.keyvault_terraform_user]

}