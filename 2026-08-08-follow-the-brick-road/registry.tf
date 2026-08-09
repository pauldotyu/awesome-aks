resource "azurerm_container_registry" "example" {
  resource_group_name    = azurerm_resource_group.example.name
  location               = azurerm_resource_group.example.location
  name                   = "acr${local.random_name}"
  sku                    = "Standard"
  admin_enabled          = false
  anonymous_pull_enabled = false
}