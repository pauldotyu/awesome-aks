data "azurerm_client_config" "current" {}

resource "random_string" "example" {
  length  = 4
  special = false
  upper   = false
  lower   = true
  numeric = false
}

resource "random_integer" "example" {
  min = 10
  max = 99
}

locals {
  random_name = "anyscale${random_integer.example.result}"
}

resource "azuread_service_principal" "example" {
  client_id    = "086bc555-6989-4362-ba30-fded273e432b" # Anyscale Kubernetes Operator Auth
  use_existing = true
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.random_name}"
  location = var.location
}
