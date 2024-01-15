resource "azurerm_kubernetes_cluster" "main" {
  name                      = "aks-${var.application_name}-${var.environment_name}"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  dns_prefix                = "${var.application_name}-${var.environment_name}"
  node_resource_group       = "${azurerm_resource_group.main.name}-cluster"
  sku_tier                  = "Standard"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                        = "systempool"
    vm_size                     = var.aks_system_pool.vm_size
    enable_auto_scaling         = true
    min_count                   = var.aks_system_pool.min_node_count
    max_count                   = var.aks_system_pool.max_node_count
    vnet_subnet_id              = azurerm_subnet.kubernetes.id
    os_disk_type                = "Ephemeral"
    os_disk_size_gb             = 30
    orchestrator_version        = var.aks_orchestration_version
    temporary_name_for_rotation = "workloadpool"

    zones = [1, 2, 3]

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.cluster_kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.cluster_kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.cluster_kubelet.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "5m"
  }

  depends_on = [azurerm_role_assignment.cluster_identity_operator]

}



resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "workloadpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.aks_workload_pool.vm_size
  enable_auto_scaling   = true
  min_count             = var.aks_workload_pool.min_node_count
  max_count             = var.aks_workload_pool.max_node_count
  vnet_subnet_id        = azurerm_subnet.kubernetes.id
  os_disk_type          = "Ephemeral"
  orchestrator_version  = var.aks_orchestration_version

  mode  = "User" # Define this node pool as a "user" aka workload node pool
  zones = [1, 2, 3]

  upgrade_settings {
    max_surge = "33%"
  }

  node_labels = {
    "role" = "workload"
  }

  node_taints = [              # this prevents pods from accidentially being scheduled on the workload node pool
    "workload=true:NoSchedule" # each pod / deployments needs a toleration for this taint
  ]

}
