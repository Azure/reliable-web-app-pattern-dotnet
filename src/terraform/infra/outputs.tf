output "keyvault_name" {
  value = azurerm_key_vault.main.name
}
output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}