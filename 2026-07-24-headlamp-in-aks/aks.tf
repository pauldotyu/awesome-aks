resource "azurerm_kubernetes_cluster" "example" {
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_resource_group.example.location
  name                      = "aks-${local.random_name}"
  dns_prefix                = "aks-${local.random_name}"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  local_account_disabled    = false

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    tenant_id              = data.azuread_client_config.current.tenant_id
    admin_group_object_ids = [data.azuread_group.example.object_id]
  }

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

resource "azurerm_role_assignment" "aks_admin" {
  principal_id         = data.azuread_group.example.object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = azurerm_kubernetes_cluster.example.id
}