resource "azurerm_dashboard_grafana" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "graf-${local.random_name}"

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.example.id
  }
}

resource "azurerm_role_assignment" "grafana1" {
  scope                = azurerm_dashboard_grafana.example.id
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Grafana Admin"
}

resource "azurerm_role_assignment" "grafana2" {
  scope                = azurerm_resource_group.example.id
  principal_id         = azurerm_dashboard_grafana.example.identity[0].principal_id
  role_definition_name = "Monitoring Data Reader"
}