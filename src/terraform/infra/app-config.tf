resource "azurerm_app_configuration" "main" {
  name                = "appcs-${var.application_name}-${var.environment_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# grant terraform access to create app config keys
resource "azurerm_role_assignment" "terraform_app_config_data_owner" {
  scope                = azurerm_app_configuration.main.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

locals {
  configuration_settings = {
    "ASPNETCORE_ENVIRONMENT"                          = "aspNetCoreEnvironment"
    "APPINSIGHTS_INSTRUMENTATIONKEY"                  = azurerm_application_insights.main.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING"           = azurerm_application_insights.main.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION"      = "~2"
    "XDT_MicrosoftApplicationInsights_Mode"           = "recommended"
    "InstrumentationEngine_EXTENSION_VERSION"         = "~1"
    "XDT_MicrosoftApplicationInsights_BaseExtensions" = "~1"
  }
}

# save instrumentation key to app config
resource "azurerm_app_configuration_key" "main" {

  for_each = local.configuration_settings

  configuration_store_id = azurerm_app_configuration.main.id
  key                    = each.key
  label                  = each.key
  value                  = each.value

  depends_on = [
    azurerm_role_assignment.terraform_app_config_data_owner
  ]
}