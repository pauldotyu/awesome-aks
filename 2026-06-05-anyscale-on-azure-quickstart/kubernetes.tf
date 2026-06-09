resource "azurerm_kubernetes_cluster" "example" {
  name                      = "aks-${local.random_name}"
  location                  = azurerm_resource_group.example.location
  resource_group_name       = azurerm_resource_group.example.name
  dns_prefix                = "aks-${local.random_name}"
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  default_node_pool {
    name       = "systempool"
    node_count = var.system_node_pool_vm_count
    vm_size    = var.system_node_pool_vm_size

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

resource "azurerm_role_assignment" "example" {
  principal_id                     = azurerm_kubernetes_cluster.example.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}