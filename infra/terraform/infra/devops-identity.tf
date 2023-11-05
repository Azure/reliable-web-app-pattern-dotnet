resource "azurerm_user_assigned_identity" "devops" {
  location            = azurerm_resource_group.main.location
  name                = "mi-${var.application_name}-${var.environment_name}-devops"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "devops_contributor" {

  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.devops.principal_id

}