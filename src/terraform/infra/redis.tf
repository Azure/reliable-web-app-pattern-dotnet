resource "azurerm_redis_cache" "main" {
  name                          = "redis-${var.application_name}-${var.environment_name}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  capacity                      = 2
  family                        = "P"
  sku_name                      = "Premium"
  enable_non_ssl_port           = false
  minimum_tls_version           = "1.2"
  zones                         = [1, 2, 3]
  public_network_access_enabled = true

  redis_configuration {
    maxmemory_reserved              = 30
    maxfragmentationmemory_reserved = 30
    maxmemory_delta                 = 30
  }
}

resource "azurerm_key_vault_secret" "redis_access_key" {
  name         = "redis-access-key"
  value        = azurerm_redis_cache.main.primary_access_key
  key_vault_id = azurerm_key_vault.main.id
}