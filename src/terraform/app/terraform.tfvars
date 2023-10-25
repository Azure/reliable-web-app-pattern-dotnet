primary_region             = "eastus2"
keyvault_readers           = ["113fa1b7-1001-48ea-a10b-fd30f231d7e2"]
keyvault_admins            = ["113fa1b7-1001-48ea-a10b-fd30f231d7e2"]
container_registry_pushers = ["328976f7-25d0-4f66-8dfb-30608805ef95"]
aks_orchestration_version  = "1.27"
aks_system_pool = {
  vm_size        = "Standard_D2_v2"
  min_node_count = 3
  max_node_count = 3
}
aks_workload_pool = {
  vm_size        = "Standard_D2_v2"
  min_node_count = 3
  max_node_count = 5
}