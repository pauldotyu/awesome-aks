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

resource "azurerm_role_assignment" "example" {
  principal_id                     = azapi_resource.aks.output.properties.identityProfile.kubeletidentity.objectId
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}

resource "azapi_update_resource" "aks_ds_ns_exclusion" {
  type        = "Microsoft.ContainerService/deploymentSafeguards@2025-05-02-preview"
  resource_id = "${azapi_resource.aks.id}/providers/Microsoft.ContainerService/deploymentSafeguards/default"

  body = {
    properties = {
      excludedNamespaces = [
        "argocd",
        "cert-manager",
      ]
    }
  }
}

resource "azapi_resource_action" "get_aks_creds" {
  type                   = azapi_resource.aks.type
  resource_id            = azapi_resource.aks.id
  action                 = "listClusterUserCredential"
  response_export_values = ["*"]
}

locals {
  kubeconfig = yamldecode(base64decode(azapi_resource_action.get_aks_creds.output.kubeconfigs[0].value))
}