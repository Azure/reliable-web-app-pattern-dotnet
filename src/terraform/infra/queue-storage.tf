locals {
  queue_storage_name = replace("st${var.application_name}${var.environment_name}", "-", "")
}

resource "azurerm_storage_account" "queue_storage" {
  name                     = local.queue_storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}