resource "local_sensitive_file" "kube_config" {
  content  = azurerm_kubernetes_cluster.main.kube_config_raw
  filename = "${path.module}/kube_config.yaml"
}