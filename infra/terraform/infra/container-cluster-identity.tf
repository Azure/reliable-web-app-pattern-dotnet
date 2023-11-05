resource "azurerm_user_assigned_identity" "cluster" {
  location            = azurerm_resource_group.main.location
  name                = "mi-${var.application_name}-${var.environment_name}-cluster"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "cluster_identity_operator" {

  scope                = azurerm_resource_group.main.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id

}

resource "azurerm_user_assigned_identity" "cluster_kubelet" {
  location            = azurerm_resource_group.main.location
  name                = "mi-${var.application_name}-${var.environment_name}-cluster-kubelet"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "cluster_kubelet_acr" {
  principal_id         = azurerm_user_assigned_identity.cluster_kubelet.principal_id
  role_definition_name = "AcrPull"
  scope                = data.azurerm_container_registry.main.id
}

resource "azurerm_role_assignment" "cluster_kubelet_app_config" {
  principal_id         = azurerm_user_assigned_identity.cluster_kubelet.principal_id
  role_definition_name = "App Configuration Data Reader"
  scope                = azurerm_app_configuration.main.id
}
