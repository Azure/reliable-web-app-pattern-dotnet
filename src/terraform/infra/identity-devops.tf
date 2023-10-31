resource "azurerm_user_assigned_identity" "devops" {
  name                = "mi-${var.application_name}-${var.environment_name}-devops"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# this is needed to allow this identity to run deployment scripts
resource "azurerm_role_assignment" "devops_contributor" {

  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id

}