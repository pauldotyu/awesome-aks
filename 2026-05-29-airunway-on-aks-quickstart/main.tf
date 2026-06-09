resource "random_integer" "example" {
  min = 10000
  max = 99999
}

resource "random_string" "example" {
  length  = 4
  upper   = false
  lower   = true
  numeric = false
  special = false
}

resource "azurerm_resource_group" "example" {
  name     = "rg-msbuildlab510${random_string.example.result}"
  location = var.location
}