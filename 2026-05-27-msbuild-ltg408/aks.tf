resource "azapi_resource" "aks" {
  type      = "Microsoft.ContainerService/managedClusters@2026-03-02-preview"
  parent_id = azurerm_resource_group.example.id
  location  = azurerm_resource_group.example.location
  tags      = var.tags
  name      = "aks-${local.random_name}"

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
          count = 3
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

resource "azurerm_role_assignment" "aks_admin" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = azapi_resource.aks.id
}