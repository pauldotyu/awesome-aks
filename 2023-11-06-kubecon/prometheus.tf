resource "azurerm_monitor_workspace" "example" {
  name                = "amon-${local.name}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

resource "azurerm_role_assignment" "example_amon_me" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Monitoring Data Reader"
  scope                = azurerm_monitor_workspace.example.id
}