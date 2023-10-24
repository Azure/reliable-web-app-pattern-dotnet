output "registry_endpoint" {
  value = azurerm_container_registry.main.login_server
}
output "keyvault_name" {
  value = azurerm_key_vault.main.name
}