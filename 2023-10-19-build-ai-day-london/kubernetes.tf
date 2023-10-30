resource "azurerm_kubernetes_cluster" "example" {
  name                = "aks-${local.name}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "aks-${local.name}"

  default_node_pool {
    name       = "system"
    vm_size    = "Standard_D4s_v4"
    node_count = 3
  }

  identity {
    type = "SystemAssigned"
  }

  monitor_metrics {
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "1m"
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.example.id
    msi_auth_for_monitoring_enabled = true
  }

  service_mesh_profile {
    mode                             = "Istio"
    external_ingress_gateway_enabled = true
    internal_ingress_gateway_enabled = true
  }

  workload_autoscaler_profile {
    keda_enabled = true
  }

  lifecycle {
    ignore_changes = [
      monitor_metrics,
      azure_policy_enabled,
      microsoft_defender
    ]
  }
}

resource "null_resource" "wait_for_aks" {
  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [azurerm_kubernetes_cluster.example]
}

resource "azapi_update_resource" "aks_network_observability" {
  type        = "Microsoft.ContainerService/managedClusters@2023-05-02-preview"
  resource_id = azurerm_kubernetes_cluster.example.id

  body = jsonencode({
    properties = {
      networkProfile = {
        monitoring = {
          enabled = true
        }
      }
    }
  })

  depends_on = [
    null_resource.wait_for_aks,
    azurerm_monitor_data_collection_rule_association.example_dce_to_aks,
    azurerm_monitor_data_collection_rule_association.example_dcr_to_aks
  ]
}

resource "local_file" "kubeconfig" {
  filename = "mykubeconfig"
  content  = azurerm_kubernetes_cluster.example.kube_config_raw
}
