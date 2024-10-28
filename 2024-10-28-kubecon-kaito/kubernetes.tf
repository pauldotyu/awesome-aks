resource "azurerm_kubernetes_cluster" "example" {
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_resource_group.example.location
  name                      = "aks-${local.random_name}"
  dns_prefix                = "aks-${local.random_name}"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2_v2"

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  monitor_metrics {
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "1m"
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.example.id
    msi_auth_for_monitoring_enabled = true
  }

  lifecycle {
    ignore_changes = [
      monitor_metrics,
      azure_policy_enabled,
      microsoft_defender
    ]
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.example.kubelet_identity[0].object_id
  scope                            = azurerm_container_registry.example.id
  role_definition_name             = "AcrPull"
  skip_service_principal_aad_check = true
}
