resource "azurerm_load_test" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "lt-${local.random_name}"
}