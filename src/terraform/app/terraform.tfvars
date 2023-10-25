primary_region             = "eastus2"
keyvault_readers           = ["113fa1b7-1001-48ea-a10b-fd30f231d7e2"]
keyvault_admins            = ["113fa1b7-1001-48ea-a10b-fd30f231d7e2"]
container_registry_pushers = ["328976f7-25d0-4f66-8dfb-30608805ef95"]
vnet_cidr_block            = "10.137.0.0/22"
aks_orchestration_version  = "1.26.6"
aks_system_pool = {
  vm_size        = "Standard_D2as_v5"
  min_node_count = 2
  max_node_count = 3
}
aks_workload_pool = {
  vm_size        = "Standard_D8as_v5"
  min_node_count = 2
  max_node_count = 3
}