resource "azuread_group" "backstage_admins" {
  display_name     = "backstage-admins"
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
}

resource "azuread_group_member" "backstage_admins" {
  group_object_id  = azuread_group.backstage_admins.object_id
  member_object_id = data.azuread_client_config.current.object_id
}

resource "azuread_group" "backstage_users" {
  display_name     = "backstage-users"
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
}

resource "azuread_group_member" "backstage_users" {
  for_each         = toset(local.backstage_users)
  group_object_id  = azuread_group.backstage_users.object_id
  member_object_id = each.key
}

resource "time_rotating" "backstage" {
  rotation_days = 180
}

resource "azuread_application" "backstage" {
  display_name     = "backstage"
  owners           = [data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"

  web {
    homepage_url = "https://backstage.${azurerm_dns_zone.example.name}/"
    redirect_uris = [
      "https://backstage.${azurerm_dns_zone.example.name}/api/auth/microsoft/handler/frame"
    ]
  }

  required_resource_access {
    resource_app_id = data.azuread_service_principal.msgraph.client_id

    resource_access {
      id   = local.msgraph_oauth2_permission_scope_ids["openid"]
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_oauth2_permission_scope_ids["profile"]
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_oauth2_permission_scope_ids["email"]
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_oauth2_permission_scope_ids["User.Read"]
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_oauth2_permission_scope_ids["offline_access"]
      type = "Scope"
    }

    dynamic "resource_access" {
      for_each = local.msgraph_app_roles
      content {
        id   = data.azuread_service_principal.msgraph.app_role_ids[resource_access.value]
        type = "Role"
      }
    }
  }

  password {
    display_name = "backstage"
    start_date   = time_rotating.backstage.id
    end_date     = timeadd(time_rotating.backstage.id, "4320h")
  }
}

resource "azuread_service_principal" "backstage" {
  client_id = azuread_application.backstage.client_id
}

resource "azuread_service_principal_delegated_permission_grant" "backstage" {
  service_principal_object_id          = azuread_service_principal.backstage.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["openid", "profile", "email", "User.Read", "offline_access"]
}

# Grant admin consent for app roles (application permissions)
resource "azuread_app_role_assignment" "backstage" {
  for_each            = toset(local.msgraph_app_roles)
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids[each.key]
  principal_object_id = azuread_service_principal.backstage.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

resource "azurerm_key_vault" "backstage" {
  name                       = "kv${local.random_name}"
  location                   = azurerm_resource_group.example.location
  resource_group_name        = azurerm_resource_group.example.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
}

resource "azurerm_role_assignment" "vault_administrator" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_key_vault.backstage.id
  role_definition_name = "Key Vault Administrator"
}

resource "azurerm_key_vault_secret" "backstage_entra_client_secret" {
  name         = "backstage-entra-client-secret"
  key_vault_id = azurerm_key_vault.backstage.id
  value        = tolist(azuread_application.backstage.password).0.value

  depends_on = [azurerm_role_assignment.vault_administrator]
}

resource "azurerm_key_vault_secret" "backstage_github_token" {
  name         = "backstage-github-token"
  key_vault_id = azurerm_key_vault.backstage.id
  value        = var.backstage_github_token

  depends_on = [azurerm_role_assignment.vault_administrator]
}

resource "local_file" "backstage_values" {
  filename = "kubernetes/backstage-values.yaml"
  content = templatefile("backstage-values.tmpl",
    {
      AZURE_CLIENT_ID      = azuread_application.backstage.client_id
      AZURE_CLIENT_SECRET  = tolist(azuread_application.backstage.password).0.value
      AZURE_TENANT_ID      = data.azuread_client_config.current.tenant_id
      AZURE_ADMIN_GROUP_ID = azuread_group.backstage_admins.object_id
      AZURE_USER_GROUP_ID  = azuread_group.backstage_users.object_id
      DNS_ZONE_NAME        = azurerm_dns_zone.example.name
    }
  )
}

resource "local_file" "backstage" {
  filename = "kubernetes/backstage.yaml"
  content = templatefile("backstage.tmpl",
    {
      DNS_ZONE_NAME = azurerm_dns_zone.example.name
    }
  )
}

resource "local_file" "external_secrets" {
  filename = "kubernetes/external-secrets.yaml"
  content = templatefile("external-secrets.tmpl",
    {
      KEY_VAULT_URL                = azurerm_key_vault.backstage.vault_uri
      TENANT_ID                    = data.azurerm_client_config.current.tenant_id
      AUTH_MICROSOFT_CLIENT_SECRET = azurerm_key_vault_secret.backstage_entra_client_secret.name
      GITHUB_TOKEN                 = azurerm_key_vault_secret.backstage_github_token.name
    }
  )
}