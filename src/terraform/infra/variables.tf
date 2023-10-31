variable "application_name" {
  type = string
}
variable "environment_name" {
  type = string
}
variable "primary_region" {
  type = string
}
variable "keyvault_readers" {
  type = list(string)
}
variable "keyvault_admins" {
  type = list(string)
}
variable "container_registry_pushers" {
  type = list(string)
}
variable "vnet_cidr_block" {
  type = string
}
variable "aks_orchestration_version" {
  type = string
}
variable "aks_system_pool" {
  type = object({
    vm_size        = string
    min_node_count = number
    max_node_count = number
  })
}
variable "aks_workload_pool" {
  type = object({
    vm_size        = string
    min_node_count = number
    max_node_count = number
  })
}
variable "sqldb_admin_username" {
  type = string
}