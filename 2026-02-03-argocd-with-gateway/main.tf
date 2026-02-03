data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}
data "azuread_user" "current" {
  object_id = data.azuread_client_config.current.object_id
}

resource "random_integer" "example" {
  min = 10
  max = 99
}

resource "azurerm_resource_group" "example" {
  name     = "rg-argocd${random_integer.example.result}"
  location = var.location
}

resource "azurerm_dns_zone" "example" {
  name                = var.dns_zone_name
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_kubernetes_cluster" "example" {
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_resource_group.example.location
  name                      = "aks-argocd${random_integer.example.result}"
  dns_prefix                = "aks-argocd${random_integer.example.result}"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name       = "default"
    node_count = 1
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].upgrade_settings,
    ]
  }
}
