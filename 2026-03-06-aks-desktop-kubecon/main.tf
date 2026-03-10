data "azurerm_client_config" "current" {}

resource "random_integer" "example" {
  min = 10
  max = 99
}

locals {
  random_name = "desktop${random_integer.example.result}"
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.random_name}"
  location = var.location
}

resource "azurerm_monitor_workspace" "example" {
  location            = azurerm_resource_group.example.location
  name                = "metrics-${local.random_name}"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_log_analytics_workspace" "example" {
  location            = azurerm_resource_group.example.location
  name                = "logs-${local.random_name}"
  resource_group_name = azurerm_resource_group.example.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
}

resource "azapi_resource" "otel" {
  type      = "Microsoft.Insights/components@2025-01-23-preview"
  name      = "otel-${local.random_name}"
  parent_id = azurerm_resource_group.example.id
  location  = azurerm_resource_group.example.location

  schema_validation_enabled = false

  body = {
    kind = "web"
    properties = {
      ApplicationId                      = "otel-${local.random_name}"
      Application_Type                   = "web"
      Flow_Type                          = "Redfield"
      Request_Source                     = "IbizaAIExtension"
      IngestionMode                      = "LogAnalytics"
      WorkspaceResourceId                = azurerm_log_analytics_workspace.example.id
      AzureMonitorWorkspaceResourceId    = azurerm_monitor_workspace.example.id
      AzureMonitorWorkspaceIngestionMode = "Enabled"
      publicNetworkAccessForIngestion    = "Enabled"
      publicNetworkAccessForQuery        = "Enabled"
    }
  }

  response_export_values = [
    "*"
  ]
}

resource "azapi_resource" "aks" {
  type      = "Microsoft.ContainerService/managedClusters@2026-01-02-preview"
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
          openTelemetryMetrics = {
            enabled = true
          }
          openTelemetryLogs = {
            enabled = true
          }
        }
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

// https://learn.microsoft.com/en-us/azure/templates/microsoft.containerservice/managedclusters/managednamespaces?pivots=deployment-language-terraform
resource "azapi_resource" "project" {
  type = "Microsoft.ContainerService/managedClusters/managedNamespaces@2026-01-02-preview"
  parent_id = azapi_resource.aks.id
  location = azurerm_resource_group.example.location
  tags = var.tags
  name = "demo"

  // this required when azapi local schema check isn't aware of the latest api version
  schema_validation_enabled = false

  body = {
    properties = {
      adoptionPolicy = "Always"
      annotations = {
        project = "demo"
        owner   = "team-demo"
      }
      defaultNetworkPolicy = {
        egress = "AllowSameNamespace"
        ingress = "AllowSameNamespace"
      }
      defaultResourceQuota = {
        cpuLimit = "500m"
        cpuRequest = "100m"
        memoryLimit = "128Mi"
        memoryRequest = "64Mi"
      }
      deletePolicy = "Delete"
      labels = {
        app = "demo"
      }
    }
  }
}