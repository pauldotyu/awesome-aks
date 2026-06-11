resource "azurerm_container_registry" "example" {
  name                = "${local.random_name}${random_string.example.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard"
  admin_enabled       = false

  tags = {
    "anyscale-cloud" = local.random_name
  }
}