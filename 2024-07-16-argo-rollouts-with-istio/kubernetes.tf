resource "azurerm_kubernetes_cluster" "example" {
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_resource_group.example.location
  name                      = "aks-${local.random_name}"
  dns_prefix                = "aks-${local.random_name}"
  workload_identity_enabled = true
  oidc_issuer_enabled       = true
  node_os_channel_upgrade   = "SecurityPatch"
  kubernetes_version        = var.k8s_version

  default_node_pool {
    name                 = "default"
    vm_size              = "Standard_D2s_v4"
    enable_auto_scaling  = true
    max_count            = 10
    min_count            = 4
    orchestrator_version = var.k8s_version

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
  }

  identity {
    type = "SystemAssigned"
  }

  monitor_metrics {
    annotations_allowed = "*"
    labels_allowed      = "*"
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.example.id
    msi_auth_for_monitoring_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "1m"
  }

  workload_autoscaler_profile {
    keda_enabled = true
  }

  service_mesh_profile {
    mode                             = "Istio"
    external_ingress_gateway_enabled = true
    internal_ingress_gateway_enabled = true
  }

  lifecycle {
    ignore_changes = [
      azure_policy_enabled,
      microsoft_defender,
    ]
  }
}

resource "azapi_update_resource" "aks_preview_features" {
  type        = "Microsoft.ContainerService/managedClusters@2024-05-02-preview"
  resource_id = azurerm_kubernetes_cluster.example.id

  body = {
    properties = {
      networkProfile = {
        advancedNetworking = {
          observability = {
            enabled = true
          }
        }
      }
    }
  }
}
