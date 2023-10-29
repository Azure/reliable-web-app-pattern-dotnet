primary_region            = "westus3"
vnet_cidr_block           = "10.37.0.0/22"
aks_orchestration_version = "1.26.6"
aks_system_pool = {
  vm_size        = "Standard_D2_v2"
  min_node_count = 2
  max_node_count = 3
}
aks_workload_pool = {
  vm_size        = "Standard_F8s_v2"
  min_node_count = 2
  max_node_count = 3
}
container_registry = {
  name                = "acrlsshareddev"
  resource_group_name = "rg-ls-shared-dev"
}