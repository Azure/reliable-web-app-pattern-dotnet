variable "application_name" {
  type = string
}
variable "environment_name" {
  type = string
}
variable "primary_region" {
  type = string
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
variable "container_registry" {
  type = object({
    name                = string
    resource_group_name = string
  })
}