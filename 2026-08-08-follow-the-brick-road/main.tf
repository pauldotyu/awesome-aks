data "azurerm_client_config" "current" {}

resource "random_integer" "example" {
  min = 10
  max = 99
}

resource "random_string" "example" {
  length  = 4
  special = false
  upper   = false
  lower   = true
  numeric = false
}

locals {
  random_name = "buildltg408${random_string.example.result}"
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.random_name}"
  location = var.location
}
