##############################################
# Azure Managed Grafana and role assignments #
##############################################

resource "azurerm_dashboard_grafana" "example" {
  name                = "amg-${local.name}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.example.id
  }
}

resource "azurerm_role_assignment" "example_amg_me" {
  scope                = azurerm_dashboard_grafana.example.id
  role_definition_name = "Grafana Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "example_amon_amg" {
  principal_id         = azurerm_dashboard_grafana.example.identity[0].principal_id
  role_definition_name = "Monitoring Data Reader"
  scope                = azurerm_monitor_workspace.example.id
}

