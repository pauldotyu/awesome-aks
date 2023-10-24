resource "azurerm_load_test" "example" {
  location            = azurerm_resource_group.example.location
  name                = "alt${local.name}"
  resource_group_name = azurerm_resource_group.example.name
}