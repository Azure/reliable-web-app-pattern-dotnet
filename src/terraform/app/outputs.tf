output "registry_endpoint" {
  value = azurerm_container_registry.main.login_server
}
output "registry_admin_username" {
  value = azurerm_container_registry.main.admin_username
}
output "registry_admin_password" {
  value     = azurerm_container_registry.main.admin_password
  sensitive = true
}