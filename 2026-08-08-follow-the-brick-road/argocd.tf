

resource "azuread_application" "example" {
  display_name                   = "app-argocd-${random_integer.example.result}"
  owners                         = [data.azuread_client_config.current.object_id]
  sign_in_audience               = "AzureADMyOrg"
  group_membership_claims        = ["ApplicationGroup"]
  fallback_public_client_enabled = true

  web {
    redirect_uris = [
      "https://argocd.${azurerm_dns_zone.example.name}/auth/callback"
    ]
  }

  public_client {
    redirect_uris = [
      "http://localhost:8085/auth/callback"
    ]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

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
  }

  optional_claims {
    id_token {
      name      = "groups"
      essential = true
    }
  }
}

resource "azuread_application_federated_identity_credential" "example" {
  application_id = azuread_application.example.id
  display_name   = azuread_application.example.display_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azapi_resource.aks.output.properties.oidcIssuerProfile.issuerURL
  subject        = "system:serviceaccount:argocd:argocd-server"
}

resource "azuread_service_principal" "example" {
  client_id = azuread_application.example.client_id
}

resource "azuread_service_principal_delegated_permission_grant" "example" {
  service_principal_object_id          = azuread_service_principal.example.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["openid", "profile", "email", "User.Read"]
}

data "azuread_group" "example" {
  display_name = "CloudNative" # Replace with your actual group name
}

resource "azuread_app_role_assignment" "example" {
  app_role_id         = "00000000-0000-0000-0000-000000000000" # Default app role
  principal_object_id = data.azuread_group.example.object_id
  resource_object_id  = azuread_service_principal.example.object_id
}

locals {
  oidc_config = <<EOT
name: Microsoft Entra ID
issuer: https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0
clientID: ${azuread_application.example.client_id}
azure:
  useWorkloadIdentity: true
requestedIDTokenClaims:
  groups:
    essential: true
requestedScopes:
  - openid
  - profile
  - email
EOT

  policy_csv = <<EOT
g, "${data.azuread_group.example.object_id}", role:admin
EOT
}

resource "azurerm_kubernetes_cluster_extension" "argocd" {
  name           = "argocd"
  cluster_id     = azapi_resource.aks.id
  extension_type = "Microsoft.ArgoCD"
  release_train  = "Preview"

  configuration_settings = {
    "azure.workloadIdentity.enabled"          = "true"
    "azure.workloadIdentity.clientId"         = azuread_application.example.client_id
    "azure.workloadIdentity.entraSSOClientId" = azuread_application.example.client_id
    "redis-ha.enabled"                        = "false"
    "global.domain"                           = "localhost:8080"
    "configs.cm.admin\\.enabled"              = "false"
    "configs.cm.oidc\\.config"                = local.oidc_config
    "configs.rbac.policy\\.csv"               = local.policy_csv
    "dex.enabled"                             = "false"
    # "redisSecretInit.resources.limits.cpu"          = "200m"
    # "redisSecretInit.resources.limits.memory"       = "128Mi"
    # "redisSecretInit.resources.requests.cpu"        = "100m"
    # "redisSecretInit.resources.requests.memory"     = "64Mi"
    # "repoServer.copyutil.resources.limits.cpu"      = "100m"
    # "repoServer.copyutil.resources.limits.memory"   = "128Mi"
    # "repoServer.copyutil.resources.requests.cpu"    = "50m"
    # "repoServer.copyutil.resources.requests.memory" = "64Mi"
    # "dex.resources.limits.cpu"                      = "50m"
    # "dex.resources.limits.memory"                   = "64Mi"
    # "dex.resources.requests.cpu"                    = "10m"
    # "dex.resources.requests.memory"                 = "32Mi"
  }

  depends_on = [
    azapi_update_resource.aks_ds_ns_exclusion,
  ]
}