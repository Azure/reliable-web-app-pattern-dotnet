data "azurerm_container_registry" "main" {

  name                = var.container_registry.name
  resource_group_name = var.container_registry.resource_group_name

}