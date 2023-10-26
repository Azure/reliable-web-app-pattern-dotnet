resource "azurerm_app_configuration" "main" {
  name                = "appcs-${var.application_name}-${var.environment_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}