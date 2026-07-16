resource "random_integer" "example" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.random_name}"
  location = var.location
}