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
          name       = "systempool"
          mode       = "System"
          count      = var.system_node_pool_vm_count
          vmSize     = var.system_node_pool_vm_size
          nodeTaints = ["CriticalAddonsOnly=true:NoSchedule"]
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
        gatewayAPI = {
          installation = "Standard"
        }
        webAppRouting = {
          gatewayAPIImplementations = {
            appRoutingIstio = {
              mode = "Enabled"
            }
          }
        }
      }
      networkProfile = {
        networkPlugin     = "azure"
        networkPluginMode = "overlay"
        networkPolicy     = "cilium"
        networkDataplane  = "cilium"
        loadBalancerSku   = "Standard"
      }
      nodeProvisioningProfile = {
        defaultNodePools = "Auto"
        mode             = "Auto"
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
    "properties.oidcIssuerProfile.issuerURL",
    "properties.identityProfile.kubeletidentity.objectId"
  ]
}

resource "azapi_resource_action" "get_aks_creds" {
  type                   = azapi_resource.aks.type
  resource_id            = azapi_resource.aks.id
  action                 = "listClusterAdminCredential"
  response_export_values = ["*"]
}

resource "azurerm_role_assignment" "example" {
  principal_id                     = azapi_resource.aks.output.properties.identityProfile.kubeletidentity.objectId
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}