resource "azapi_resource" "aks" {
  type      = "Microsoft.ContainerService/managedClusters@2026-03-02-preview"
  parent_id = azurerm_resource_group.example.id
  location  = azurerm_resource_group.example.location
  name      = "aks-${local.random_name}"

  // this required when azapi local schema check isn't aware of the latest api version
  schema_validation_enabled = false

  body = {
    identity = {
      type = "SystemAssigned"
    },
    properties = {
      dnsPrefix = "aks-${local.random_name}"
      agentPoolProfiles = [
        {
          name   = "systempool"
          mode   = "System"
          count  = var.system_node_pool_vm_count
          vmSize = var.system_node_pool_vm_size
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
      ingressProfile = {
        applicationLoadBalancer = {
          enabled = false
        }
        gatewayAPI = {
          installation = "Standard"
        }
        webAppRouting = {
          enabled = false
          gatewayAPIImplementations = {
            appRoutingIstio = {
              mode = "Enabled"
            }
          }
          nginx = {
            defaultIngressControllerType = "None"
          }
        }
      }
      oidcIssuerProfile = {
        enabled = true
      }
      securityProfile = {
        workloadIdentity = {
          enabled = true
        }
      }
    }
    sku = {
      name = "Base"
      tier = "Standard"
    }
  }

  response_export_values = [
    "*"
  ]
}

resource "azurerm_role_assignment" "aks_admin" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = azapi_resource.aks.id
}

# resource "azurerm_kubernetes_cluster_node_pool" "example" {
#   name                        = "raypool"
#   kubernetes_cluster_id       = azurerm_kubernetes_cluster.example.id
#   vm_size                     = var.ray_node_pool_vm_size
#   node_count                  = 1
#   min_count                   = 1
#   max_count                   = var.ray_node_pool_max_vm_count
#   auto_scaling_enabled        = true
#   gpu_driver                  = "None"
#   temporary_name_for_rotation = "temp${random_integer.example.result}"

#   upgrade_settings {
#     drain_timeout_in_minutes      = 0
#     max_surge                     = "10%"
#     node_soak_duration_in_minutes = 0
#   }
# }

resource "azurerm_role_assignment" "example" {
  principal_id                     = azapi_resource.aks.output.properties.identityProfile.kubeletidentity.objectId
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}
