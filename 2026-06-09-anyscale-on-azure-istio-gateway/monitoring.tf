resource "azurerm_monitor_workspace" "example" {
  location            = azurerm_resource_group.example.location
  name                = "metrics-${local.random_name}"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_log_analytics_workspace" "example" {
  location            = azurerm_resource_group.example.location
  name                = "logs-${local.random_name}"
  resource_group_name = azurerm_resource_group.example.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
}

resource "azapi_resource" "otel" {
  type      = "Microsoft.Insights/components@2025-01-23-preview"
  name      = "otel-${local.random_name}"
  parent_id = azurerm_resource_group.example.id
  location  = azurerm_resource_group.example.location

  schema_validation_enabled = false

  body = {
    kind = "web"
    properties = {
      ApplicationId                      = "otel-${local.random_name}"
      Application_Type                   = "web"
      Flow_Type                          = "Redfield"
      Request_Source                     = "IbizaAIExtension"
      IngestionMode                      = "LogAnalytics"
      WorkspaceResourceId                = azurerm_log_analytics_workspace.example.id
      AzureMonitorWorkspaceResourceId    = azurerm_monitor_workspace.example.id
      AzureMonitorWorkspaceIngestionMode = "Enabled"
      publicNetworkAccessForIngestion    = "Enabled"
      publicNetworkAccessForQuery        = "Enabled"
    }
  }

  response_export_values = [
    "properties.OTLPLogsEndpoint",
    "properties.OTLPMetricsEndpoint",
    "properties.OTLPTracesEndpoint"
  ]
}