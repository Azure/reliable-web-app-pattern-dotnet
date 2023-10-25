resource "azurerm_user_assigned_identity" "cluster" {
  location            = azurerm_resource_group.main.location
  name                = "mi-${var.application_name}-${var.environment_name}-cluster"
  resource_group_name = azurerm_resource_group.main.name
}


resource "azurerm_user_assigned_identity" "cluster_kubelet" {
  location            = azurerm_resource_group.main.location
  name                = "mi-${var.application_name}-${var.environment_name}-cluster-kubelet"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.application_name}-${var.environment_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.application_name}-${var.environment_name}"

  default_node_pool {
    name       = "default"
    node_count = 5
    vm_size    = "Standard_D2_v2"
    zones      = [1, 2, 3]
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  kubelet_identity {
    user_assigned_identity_id = azurerm_user_assigned_identity.cluster_kubelet.id
  }

}

resource "azurerm_role_assignment" "cluster_kubelet" {
  principal_id                     = azurerm_user_assigned_identity.cluster_kubelet.principal_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}