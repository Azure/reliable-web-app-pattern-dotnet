locals {
  container_registry_name = replace("acr${var.application_name}${var.environment_name}", "-", "")
}

resource "azurerm_container_registry" "main" {
  name                = local.container_registry_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Premium"
  admin_enabled       = false
}

resource "azurerm_role_assignment" "acr_push" {

  count = length(var.container_registry_pushers)

  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = var.container_registry_pushers[count.index]

}