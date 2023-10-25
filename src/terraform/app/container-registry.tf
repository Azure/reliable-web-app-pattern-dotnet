data "azurerm_container_registry" "main" {
  name                = replace("acr${var.application_name}shared${var.environment_name}", "-", "")
  resource_group_name = "test"
}