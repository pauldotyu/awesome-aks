# ---------------------------------------------------------------------------
# AKS cluster: single system node pool (scale up as needed), with OIDC issuer
# and Workload Identity enabled and a system-assigned managed identity.
# ---------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "example" {
  name                = local.aks_name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = local.aks_name
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  # Required so cert-manager and External Secrets Operator can authenticate to
  # Azure via federated credentials (Azure Workload Identity).
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type = "SystemAssigned"
  }

  # azurerm 5.x requires a node_provisioning_profile. "Manual" + default_node_pools
  # "None" means AKS does not auto-provision node pools (this is a standard AKS
  # cluster, not AKS Automatic) and the single system pool below is used.
  node_provisioning_profile {
    mode               = "Manual"
    default_node_pools = "None"
  }

  # Minimal, usable single-node system pool. Raise node_count (or add a
  # separate node_pool block) when the environment must be scaled.
  default_node_pool {
    name       = "system"
    node_count = 1
    vm_size    = "Standard_D2s_v5"
  }

  # Ignore fields AKS rotates on its own.
  lifecycle {
    ignore_changes = [
      default_node_pool[0].upgrade_settings,
    ]
  }
}

# Give the current Azure user full cluster-admin RBAC so kubectl / az aks
# get-credentials work after provisioning.
resource "azurerm_role_assignment" "aks_admin" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = azurerm_kubernetes_cluster.example.id
}
