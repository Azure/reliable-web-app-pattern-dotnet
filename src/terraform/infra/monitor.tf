resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.application_name}-${var.environment_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
/*
resource "azurerm_monitor_workspace" "main" {
  name                = "mamw-${var.application_name}-${var.environment_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_monitor_data_collection_endpoint" "main" {
  name                          = "mdce-${var.application_name}-${var.environment_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  kind                          = "Linux"
}

resource "azurerm_monitor_data_collection_rule_association" "aks" {
  name                    = "dcra-aks-${var.application_name}-${var.environment_name}"
  target_resource_id      = azurerm_kubernetes_cluster.main.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.example.id
  description             = "example"
}
*/