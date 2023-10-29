output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}
output "cluster_kubelet_id" {
  value = azurerm_user_assigned_identity.cluster_kubelet.principal_id
}