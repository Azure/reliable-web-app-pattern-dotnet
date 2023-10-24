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