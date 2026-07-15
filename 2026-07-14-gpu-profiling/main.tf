data "azurerm_client_config" "current" {}

resource "random_integer" "example" {
  min = 100
  max = 999
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.random_name}"
  location = var.location
}
