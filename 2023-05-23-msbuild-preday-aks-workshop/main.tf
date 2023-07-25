terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 2.39.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.56.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

data "azurerm_client_config" "pre03" {}
data "azuread_domains" "pre03" {}

resource "random_password" "pre03" {
  length  = 16
  special = true
}

resource "random_string" "pre03" {
  length  = 4
  lower   = true
  upper   = false
  special = false
}

resource "azurerm_resource_group" "pre03" {
  name     = "rg-shared"
  location = "southcentralus"
}

resource "azurerm_log_analytics_workspace" "pre03" {
  name                = "alogshared${random_string.pre03.result}"
  resource_group_name = azurerm_resource_group.pre03.name
  location            = azurerm_resource_group.pre03.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_dashboard_grafana" "pre03" {
  name                              = "amgshared${random_string.pre03.result}"
  resource_group_name               = azurerm_resource_group.pre03.name
  location                          = azurerm_resource_group.pre03.location
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = true
  public_network_access_enabled     = true

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_monitor_workspace" "pre03" {
  name                = "amonshared${random_string.pre03.result}"
  resource_group_name = azurerm_resource_group.pre03.name
  location            = azurerm_resource_group.pre03.location
}

resource "azurerm_role_assignment" "pre03_amg_rbac_me" {
  scope                = azurerm_dashboard_grafana.pre03.id
  role_definition_name = "Grafana Admin"
  principal_id         = data.azurerm_client_config.pre03.object_id
}

resource "azurerm_role_assignment" "pre03_amon_rbac_amg" {
  scope                = azurerm_monitor_workspace.pre03.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.pre03.identity[0].principal_id
}

resource "azurerm_role_assignment" "pre03_amon_rbac_me" {
  scope                = azurerm_monitor_workspace.pre03.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = data.azurerm_client_config.pre03.object_id
}

# resource "azurerm_container_app_environment" "pre03" {
#   name                       = "welcome-to-build-aca-env"
#   resource_group_name        = azurerm_resource_group.pre03.name
#   location                   = azurerm_resource_group.pre03.location
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.pre03.id

#   lifecycle {
#     ignore_changes = [log_analytics_workspace_id]
#   }
# }

resource "azurerm_load_test" "pre03" {
  name                = "altshared${random_string.pre03.result}"
  resource_group_name = azurerm_resource_group.pre03.name
  location            = azurerm_resource_group.pre03.location
}

module "pre03" {
  source = "./modules/pre03"

  for_each = { for u in var.deployment_locations : u.location => u }

  user_count                        = each.value["count"]
  user_offset                       = each.value["offset"]
  location                          = each.value["location"]
  vm_sku                            = each.value["vm_sku"]
  user_password                     = random_password.pre03.result
  primary_domain                    = data.azuread_domains.pre03.domains[0].domain_name
  unique_string                     = random_string.pre03.result
  shared_resource_group_id          = azurerm_resource_group.pre03.id
  shared_log_analytics_workspace_id = azurerm_log_analytics_workspace.pre03.id
  managed_grafana_resource_id       = azurerm_dashboard_grafana.pre03.id

  depends_on = [
    azurerm_resource_group.pre03,
    azurerm_dashboard_grafana.pre03,
    azurerm_monitor_workspace.pre03,
    azurerm_role_assignment.pre03_amg_rbac_me,
    azurerm_role_assignment.pre03_amon_rbac_amg,
    azurerm_role_assignment.pre03_amon_rbac_me,
  ]
}

# # todo: Microsoft.Insights/dataCollectionEndpoints
# # todo: microsoft.monitor/accounts
# # todo: Microsoft.Insights/dataCollectionRules
# # todo: Microsoft.Authorization/roleAssignments
# # todo: Microsoft.AlertsManagement/prometheusRuleGroups
# # todo: Microsoft.Insights/dataCollectionRuleAssociations
# # todo: microsoft.dashboard/grafana