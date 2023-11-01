primary_region             = "westus3"
keyvault_readers           = ["113fa1b7-1001-48ea-a10b-fd30f231d7e2"]
keyvault_admins            = ["113fa1b7-1001-48ea-a10b-fd30f231d7e2"]
container_registry_pushers = ["328976f7-25d0-4f66-8dfb-30608805ef95"]
vnet_cidr_block            = "10.137.0.0/22"
aks_orchestration_version  = "1.26.6"
aks_system_pool = {
  vm_size        = "Standard_D2s_v3"
  min_node_count = 2
  max_node_count = 3
}
aks_workload_pool = {
  vm_size        = "Standard_F8s_v2"
  min_node_count = 2
  max_node_count = 3
}
sqldb_admin_username   = "admin_user"
web_api_application_id = "f43f355e-6c78-4498-b441-605dd0841041"
web_app_application_id = "78dc7090-8db4-47c6-915a-ae01e3bde86d"
container_registry = {
  name                = "acrrelazappsharedlab1025"
  resource_group_name = "rg-relaz-app-shared-lab1025"
}