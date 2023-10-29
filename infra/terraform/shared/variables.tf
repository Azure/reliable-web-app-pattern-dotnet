variable "application_name" {
  type = string
}
variable "environment_name" {
  type = string
}
variable "primary_region" {
  type = string
}
variable "container_registry_pushers" {
  type        = list(string)
  description = "Must be Object IDs you DOLT!"
}