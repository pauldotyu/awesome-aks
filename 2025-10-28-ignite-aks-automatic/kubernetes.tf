// https://learn.microsoft.com/azure/templates/microsoft.containerservice/managedclusters?pivots=deployment-language-terraform
resource "azapi_resource" "aks" {
  type      = "Microsoft.ContainerService/managedClusters@2025-08-02-preview"
  parent_id = azapi_resource.rg.id
  location  = azapi_resource.rg.location
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
            logAnalyticsWorkspaceResourceID = azapi_resource.law.id
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
          enabled = true,
          logAnalyticsWorkspaceResourceId = azapi_resource.law.id
        }
        appMonitoring = {
          autoInstrumentation = {
            enabled = true
          }
          openTelemetryMetrics = {
            enabled = true
          }
          openTelemetryLogs = {
            enabled = true
          }
        }
      }
      hostedSystemProfile = {
        enabled = true
      }
      ingressProfile = {
        gatewayAPI = {
          installation = "Standard"
        }
      }
      serviceMeshProfile = {
        istio = {
          components = {
            ingressGateways = [
              {
                enabled = true
                mode = "External"
              }
            ]
          }
          revisions = [
            "asm-1-26"
          ]
        }
        mode = "Istio"
      }
    }
    sku = {
      name = "Automatic"
      tier = "Standard"
    }
  }

  response_export_values = [
    "properties"
    # if you want to limit the exported values, just list what you need...
    # "properties.identityProfile.kubeletidentity.objectId",
    # "properties.oidcIssuerProfile.issuerURL",
    # "properties.nodeResourceGroup"
  ]

  timeouts {
    create = "60m"
    delete = "60m"
  }
}

resource "random_uuid" "acr_pull" {}
resource "azapi_resource" "acr_pull" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.acr_pull.result
  parent_id = azapi_resource.acr.id
  body = {
    properties = {
      principalId      = azapi_resource.aks.output.properties.identityProfile.kubeletidentity.objectId
      roleDefinitionId = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d" // AcrPull
      principalType    = "ServicePrincipal"
    }
  }
}

resource "random_uuid" "aks_cluster_admin" {}
resource "azapi_resource" "aks_cluster_admin" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.aks_cluster_admin.result
  parent_id = azapi_resource.aks.id
  body = {
    properties = {
      principalId      = data.azurerm_client_config.current.object_id
      roleDefinitionId = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b" // Azure Kubernetes Service RBAC Cluster Admin
      principalType    = "User"
    }
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.servicelinker/linkers?pivots=deployment-language-terraform
resource "azapi_resource" "oai_linker" {
  type      = "Microsoft.ServiceLinker/linkers@2024-07-01-preview"
  name      = "openai"
  parent_id = azapi_resource.aks.id
  body = {
    properties = {
      clientType = "none"
      scope      = "demo"
      targetService = {
        type = "AzureResource"
        id   = azapi_resource.oai.id
      }
      authInfo = {
        authType       = "userAssignedIdentity"
        clientId       = azapi_resource.oai_id.output.properties.clientId
        subscriptionId = data.azurerm_client_config.current.subscription_id
      }
    }
  }
  response_export_values = [
    "*"
  ]
}

#"properties" = {
#  "authInfo" = {
#    "authMode" = null
#    "authType" = "userAssignedIdentity"
#    "clientId" = "82b95518-41f5-4d9f-9b14-0f8eac16cc84"
#    "deleteOrUpdateBehavior" = null
#    "roles" = null
#    "subscriptionId" = "90ab3701-83f0-4ba1-a90a-f2e68683adab"
#    "userName" = null
#  }
#  "clientType" = "none"
#  "configurationInfo" = null
#  "provisioningState" = "Succeeded"
#  "publicNetworkSolution" = null
#  "scope" = "demo"
#  "secretStore" = null
#  "targetService" = {
#    "id" = "/subscriptions/90ab3701-83f0-4ba1-a90a-f2e68683adab/resourceGroups/rg-ignitedlab59/providers/Microsoft.CognitiveServices/accounts/oai-ignitedlab59"
#    "resourceProperties" = null
#    "type" = "AzureResource"
#  }
#  "vNetSolution" = null
#}