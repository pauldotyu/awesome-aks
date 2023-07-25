data "azurerm_client_config" "pre03" {}

resource "azuread_user" "pre03" {
  count               = var.user_count
  user_principal_name = "user${count.index + var.user_offset + 1}@${var.primary_domain}"
  display_name        = "User ${count.index + var.user_offset + 1}"
  mail_nickname       = "user${count.index + var.user_offset + 1}"
  password            = var.user_password
}

resource "azurerm_resource_group" "pre03" {
  count    = var.user_count
  name     = "rg-user${count.index + var.user_offset + 1}"
  location = var.location
}

resource "azurerm_role_assignment" "pre03_rg_rbac_user" {
  count                = var.user_count
  role_definition_name = "Owner"
  scope                = azurerm_resource_group.pre03[count.index].id
  principal_id         = azuread_user.pre03[count.index].object_id
}

resource "azuread_application" "pre03" {
  count        = var.user_count
  display_name = "user${count.index + var.user_offset + 1}"
  owners       = [azuread_user.pre03[count.index].object_id]
}

resource "azuread_service_principal" "pre03" {
  count                        = var.user_count
  application_id               = azuread_application.pre03[count.index].application_id
  app_role_assignment_required = true
  owners                       = [azuread_user.pre03[count.index].object_id]
}

resource "azurerm_role_assignment" "pre03_sp_rbac" {
  count                = var.user_count
  scope                = azurerm_resource_group.pre03[count.index].id
  role_definition_name = "Owner"
  principal_id         = azuread_service_principal.pre03[count.index].object_id
}

resource "azurerm_container_registry" "pre03" {
  count                  = var.user_count
  name                   = "acruser${count.index + var.user_offset + 1}${var.unique_string}"
  resource_group_name    = azurerm_resource_group.pre03[count.index].name
  location               = azurerm_resource_group.pre03[count.index].location
  sku                    = "Standard"
  admin_enabled          = true
  anonymous_pull_enabled = true
}

resource "azurerm_kubernetes_cluster" "pre03" {
  count               = var.user_count
  name                = "aks-user${count.index + var.user_offset + 1}"
  resource_group_name = azurerm_resource_group.pre03[count.index].name
  location            = azurerm_resource_group.pre03[count.index].location
  dns_prefix          = "aks-user${count.index + var.user_offset + 1}"

  default_node_pool {
    name                = "default"
    enable_auto_scaling = true
    max_count           = 3
    min_count           = 1
    vm_size             = var.vm_sku
  }

  oms_agent {
    log_analytics_workspace_id = var.shared_log_analytics_workspace_id
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "1m"
  }

  service_mesh_profile {
    mode = "Istio"
  }

  workload_autoscaler_profile {
    keda_enabled = true
  }

  # web_app_routing {
  #   dns_zone_id = ""
  # }

  lifecycle {
    ignore_changes = [
      monitor_metrics
    ]
  }
}

resource "azurerm_role_assignment" "pre03_acr_rbac_aks" {
  count                            = var.user_count
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.pre03[count.index].id
  principal_id                     = azurerm_kubernetes_cluster.pre03[count.index].kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# use local provisioner to enable istio ingress gateway on each AKS cluster
resource "null_resource" "pre03" {
  count = var.user_count

  provisioner "local-exec" {
    command = "az aks mesh enable-ingress-gateway --resource-group ${azurerm_resource_group.pre03[count.index].name} --name ${azurerm_kubernetes_cluster.pre03[count.index].name} --ingress-gateway-type external"
  }

  depends_on = [
    azurerm_kubernetes_cluster.pre03,
  ]
}

# resource "azurerm_storage_account" "pre03" {
#   count                    = var.user_count
#   name                     = "sauser${count.index + var.user_offset + 1}${var.unique_string}"
#   resource_group_name      = azurerm_resource_group.pre03[count.index].name
#   location                 = azurerm_resource_group.pre03[count.index].location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
# }

# resource "azurerm_storage_share" "pre03" {
#   count                = var.user_count
#   name                 = "cloudshell"
#   storage_account_name = azurerm_storage_account.pre03[count.index].name
#   access_tier          = "Hot"
#   quota                = 6
# }

resource "azurerm_user_assigned_identity" "pre03" {
  count               = var.user_count
  location            = azurerm_resource_group.pre03[count.index].location
  resource_group_name = azurerm_resource_group.pre03[count.index].name
  name                = "aks-user${count.index + var.user_offset + 1}-identity"
}

resource "azurerm_federated_identity_credential" "pre03_ava" {
  count               = var.user_count
  name                = "aks-user${count.index + var.user_offset + 1}-federated-default"
  resource_group_name = azurerm_resource_group.pre03[count.index].name
  issuer              = azurerm_kubernetes_cluster.pre03[count.index].oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.pre03[count.index].id
  subject             = "system:serviceaccount:default:azure-voting-app-serviceaccount"
  audience = [
    "api://AzureADTokenExchange"
  ]
}

resource "azurerm_federated_identity_credential" "pre03_rat" {
  count               = var.user_count
  name                = "aks-user${count.index + var.user_offset + 1}-federated-ratify"
  resource_group_name = azurerm_resource_group.pre03[count.index].name
  issuer              = azurerm_kubernetes_cluster.pre03[count.index].oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.pre03[count.index].id
  subject             = "system:serviceaccount:gatekeeper-system:ratify-admin"
  audience = [
    "api://AzureADTokenExchange"
  ]
}

resource "azurerm_key_vault" "pre03" {
  count                      = var.user_count
  name                       = "akvuser${count.index + var.user_offset + 1}${var.unique_string}"
  location                   = azurerm_resource_group.pre03[count.index].location
  resource_group_name        = azurerm_resource_group.pre03[count.index].name
  tenant_id                  = data.azurerm_client_config.pre03.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  sku_name                   = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.pre03.tenant_id
    object_id = data.azurerm_client_config.pre03.object_id

    certificate_permissions = [
      "Backup",
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "Purge",
      "Recover",
      "Restore",
      "SetIssuers",
      "Update"
    ]

    key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey",
      "Release",
      "Rotate",
      "GetRotationPolicy",
      "SetRotationPolicy"
    ]

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set"
    ]

    storage_permissions = [
      "Backup",
      "Delete",
      "DeleteSAS",
      "Get",
      "GetSAS",
      "List",
      "ListSAS",
      "Purge",
      "Recover",
      "RegenerateKey",
      "Restore",
      "Set",
      "SetSAS",
      "Update"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.pre03.tenant_id
    object_id = azuread_user.pre03[count.index].object_id

    certificate_permissions = [
      "Backup",
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "Purge",
      "Recover",
      "Restore",
      "SetIssuers",
      "Update"
    ]

    key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey",
      "Release",
      "Rotate",
      "GetRotationPolicy",
      "SetRotationPolicy"
    ]

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set"
    ]

    storage_permissions = [
      "Backup",
      "Delete",
      "DeleteSAS",
      "Get",
      "GetSAS",
      "List",
      "ListSAS",
      "Purge",
      "Recover",
      "RegenerateKey",
      "Restore",
      "Set",
      "SetSAS",
      "Update"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.pre03.tenant_id
    object_id = azurerm_user_assigned_identity.pre03[count.index].principal_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    certificate_permissions = [
      "Get"
    ]
  }
}

resource "azurerm_key_vault_certificate" "ratify-cert" {
  count        = var.user_count
  name         = "ratify"
  key_vault_id = azurerm_key_vault.pre03[count.index].id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.3"]

      key_usage = [
        "digitalSignature",
      ]

      subject            = "CN=example.com"
      validity_in_months = 12
    }
  }
}

resource "azurerm_role_assignment" "pre03_amg_rbac_user" {
  count                = var.user_count
  scope                = var.managed_grafana_resource_id
  role_definition_name = "Grafana Admin"
  principal_id         = azuread_user.pre03[count.index].object_id
}

resource "azurerm_role_assignment" "pre03_amg_rbac_useridentity" {
  count                = var.user_count
  scope                = var.managed_grafana_resource_id
  role_definition_name = "Grafana Admin"
  principal_id         = azurerm_user_assigned_identity.pre03[count.index].principal_id
}

resource "azurerm_role_assignment" "pre03_mcrg_rbac_user" {
  count                = var.user_count
  role_definition_name = "Owner"
  scope                = azurerm_kubernetes_cluster.pre03[count.index].node_resource_group_id
  principal_id         = azuread_user.pre03[count.index].object_id
}

resource "azurerm_role_assignment" "pre03_sharedrg_rbac_user" {
  count                = var.user_count
  role_definition_name = "Owner"
  scope                = var.shared_resource_group_id
  principal_id         = azuread_user.pre03[count.index].object_id
}

# # todo: Microsoft.Insights/dataCollectionEndpoints
# # todo: microsoft.monitor/accounts
# # todo: Microsoft.Insights/dataCollectionRules
# # todo: Microsoft.Authorization/roleAssignments
# # todo: Microsoft.AlertsManagement/prometheusRuleGroups
# # todo: Microsoft.Insights/dataCollectionRuleAssociations
# # todo: microsoft.dashboard/grafana