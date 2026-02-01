

resource "random_integer" "example" {
  min = 10
  max = 99
}

resource "random_pet" "example" {
  length    = 2
  separator = ""
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "rg-certmanager${random_integer.example.result}"
  location = var.location
}

resource "azurerm_dns_zone" "example" {
  name                = "${random_pet.example.id}.com"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_kubernetes_cluster" "example" {
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_resource_group.example.location
  name                      = "aks-certmanager${random_integer.example.result}"
  dns_prefix                = "aks-certmanager${random_integer.example.result}"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  local_account_disabled    = false

  default_node_pool {
    name       = "default"
    node_count = 1

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "helm_release" "example" {
  name             = "cert-manager"
  chart            = "oci://quay.io/jetstack/charts/cert-manager"
  version          = "v1.19.2"
  namespace        = "cert-manager"
  create_namespace = true

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    }
  ]
}
