resource "azurerm_kubernetes_cluster" "control" {
  name                              = local.aks_control_name
  location                          = azurerm_resource_group.example.location
  resource_group_name               = azurerm_resource_group.example.name
  dns_prefix                        = local.aks_control_name
  kubernetes_version                = var.control_kubernetes_version
  sku_tier                          = "Free"
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  local_account_disabled            = true
  role_based_access_control_enabled = true
  automatic_upgrade_channel         = "patch"
  node_os_upgrade_channel           = "NodeImage"

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = var.control_vm_size

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  node_provisioning_profile {
    mode = "Auto"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    outbound_type       = "loadBalancer"
    load_balancer_sku   = "standard"
  }

  # Ignore fields we customized below
  lifecycle {
    ignore_changes = [web_app_routing]
  }
}

resource "azapi_update_resource" "add_cluster_features" {
  type        = "Microsoft.ContainerService/managedClusters@2026-08-02-preview"
  resource_id = azurerm_kubernetes_cluster.control.id
  body = {
    properties = {
      ingressProfile = {
        gatewayAPI = {
          installation = "Standard"
        }
        webAppRouting = {
          enabled = true
          gatewayAPIImplementations = {
            appRoutingIstio = {
              mode = "Enabled"
            }
          }
        }
      }
    }
  }
}

resource "azurerm_role_assignment" "control_cluster_access" {
  scope                = azurerm_kubernetes_cluster.control.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}

resource "azapi_resource" "aks_worker" {
  type      = "Microsoft.ContainerService/managedClusters@2026-03-02-preview"
  parent_id = azurerm_resource_group.example.id
  location  = azurerm_resource_group.example.location
  tags      = var.tags
  name      = local.aks_worker_name

  // this required when azapi local schema check isn't aware of the latest api version
  schema_validation_enabled = false

  body = {
    identity = {
      type = "SystemAssigned"
    },
    properties = {
      agentPoolProfiles = [
        {
          name  = "systempool"
          mode  = "System"
          count = 1
        }
      ]
      addonProfiles = {
        omsagent = {
          enabled = true
          config = {
            logAnalyticsWorkspaceResourceID = azurerm_log_analytics_workspace.example.id
            useAADAuth                      = "true"
          }
        }
      }
      azureMonitorProfile = {
        metrics = {
          enabled = true,
          kubeStateMetrics = {
            metricLabelsAllowlist      = "",
            metricAnnotationsAllowList = ""
          }
        }
        containerInsights = {
          enabled                         = true,
          logAnalyticsWorkspaceResourceId = azurerm_log_analytics_workspace.example.id
        }
        appMonitoring = {
          autoInstrumentation = {
            enabled = true
          }
          openTelemetryLogsAndTraces = {
            enabled = true
          }
          openTelemetryMetrics = {
            enabled = true
          }
        }
      }
      hostedSystemProfile = {
        enabled = true
      }
    }
    sku = {
      name = "Automatic"
      tier = "Standard"
    }
  }

  response_export_values = [
    "*"
  ]
}

resource "azurerm_role_assignment" "worker_cluster_access" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = azapi_resource.aks_worker.id
}
