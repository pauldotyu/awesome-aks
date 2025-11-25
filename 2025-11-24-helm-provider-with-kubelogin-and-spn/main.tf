data "azurerm_client_config" "current" {}

resource "random_integer" "example" {
  min = 10
  max = 99
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.random_name}"
  location = var.location
}

resource "azurerm_monitor_workspace" "example" {
  location            = azurerm_resource_group.example.location
  name                = "prom-${local.random_name}"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_log_analytics_workspace" "example" {
  location            = azurerm_resource_group.example.location
  name                = "logs-${local.random_name}"
  resource_group_name = azurerm_resource_group.example.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
}

module "avm-res-containerservice-managedcluster" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.4.0-pre1"

  parent_id = azurerm_resource_group.example.id
  location  = azurerm_resource_group.example.location
  name      = "aks-${local.random_name}"
  sku = {
    name = "Automatic"
    tier = "Standard"
  }

  # observability settings
  onboard_monitoring         = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id
  prometheus_workspace_id    = azurerm_monitor_workspace.example.id
  onboard_alerts             = true
  alert_email                = "pauyu@microsoft.com"

  # role assignments
  role_assignments = {
    cluster_admin = {
      role_definition_id_or_name = "Azure Kubernetes Service RBAC Cluster Admin"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }
}

resource "helm_release" "example" {
  name       = "aks-store-demo"
  repository = "https://azure-samples.github.io/aks-store-demo"
  chart      = "aks-store-demo-chart"
  version    = "1.4.0"

  # Allow upgrading existing installation
  replace           = true
  force_update      = true
  recreate_pods     = false
  cleanup_on_fail   = true
  max_history       = 3
}