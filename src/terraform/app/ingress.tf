resource "azurerm_public_ip" "aks_ingress" {

  name                = "pip-${var.application_name}-${var.environment_name}-ingress"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  allocation_method   = "Static"

  domain_name_label = "${var.application_name}-${var.environment_name}-cluster"

  zones = ["1", "2", "3"]

}

locals {
  backend_address_pool_name      = "${var.application_name}-${var.environment_name}-beap"
  frontend_port_name             = "${var.application_name}-${var.environment_name}-feport"
  frontend_ip_configuration_name = "${var.application_name}-${var.environment_name}-feip"
  http_setting_name              = "${var.application_name}-${var.environment_name}-be-htst"
  listener_name                  = "${var.application_name}-${var.environment_name}-httplstn"
  request_routing_rule_name      = "${var.application_name}-${var.environment_name}-rqrt"
  redirect_configuration_name    = "${var.application_name}-${var.environment_name}-rdrcfg"
}

resource "azurerm_application_gateway" "network" {
  name                = "agw-${var.application_name}-${var.environment_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.ingress.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.aks_ingress.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}