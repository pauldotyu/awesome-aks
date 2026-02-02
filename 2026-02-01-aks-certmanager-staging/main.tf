

resource "random_integer" "example" {
  min = 10
  max = 99
}

resource "random_uuid" "example" {}

locals {
  lb_dns_label = "lb-${random_uuid.example.result}"
}

resource "azurerm_resource_group" "example" {
  name     = "rg-certmanager${random_integer.example.result}"
  location = var.location
}

resource "azurerm_dns_zone" "example" {
  name                = var.dns_zone_name
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_dns_cname_record" "example" {
  name                = "www"
  zone_name           = azurerm_dns_zone.example.name
  resource_group_name = azurerm_resource_group.example.name
  ttl                 = 300
  record              = "${local.lb_dns_label}.${azurerm_kubernetes_cluster.example.location}.cloudapp.azure.com"
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

resource "azurerm_user_assigned_identity" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "cert-manager"
}

resource "azurerm_role_assignment" "example" {
  principal_id                     = azurerm_user_assigned_identity.example.principal_id
  scope                            = azurerm_dns_zone.example.id
  role_definition_name             = "DNS Zone Contributor"
  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "example" {
  resource_group_name = azurerm_resource_group.example.name
  parent_id           = azurerm_user_assigned_identity.example.id
  name                = "cert-manager"
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  audience            = ["api://AzureADTokenExchange"]
  subject             = "system:serviceaccount:cert-manager:cert-manager"
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
    },
    {
      name  = "podLabels.azure\\.workload\\.identity/use"
      value = "true"
      type  = "string"
    },
    {
      name  = "serviceAccount.annotations.azure\\.workload\\.identity/client-id"
      value = azurerm_user_assigned_identity.example.client_id
      type  = "string"
    }
  ]
}
