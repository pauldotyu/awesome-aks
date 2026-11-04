resource "azuread_group" "argocd_admins" {
  display_name     = "argocd-admins"
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
}

resource "azuread_group_member" "argocd_admins" {
  group_object_id  = azuread_group.argocd_admins.object_id
  member_object_id = data.azuread_client_config.current.object_id
}

resource "azuread_group" "argocd_users" {
  display_name     = "argocd-users"
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
}

resource "azuread_group_member" "argocd_users" {
  for_each         = toset(local.argocd_users)
  group_object_id  = azuread_group.argocd_users.object_id
  member_object_id = each.value
}

resource "azuread_application" "argocd" {
  display_name                   = "${local.random_name}-argocd"
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
  }

  optional_claims {
    id_token {
      name      = "groups"
      essential = true
    }
  }
}

resource "azuread_application_federated_identity_credential" "argocd" {
  application_id = azuread_application.argocd.id
  display_name   = azuread_application.argocd.display_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azurerm_kubernetes_cluster.control.oidc_issuer_url
  subject        = "system:serviceaccount:argocd:argocd-server"
}

resource "azuread_service_principal" "argocd" {
  client_id = azuread_application.argocd.client_id
}

resource "azuread_service_principal_delegated_permission_grant" "argocd" {
  service_principal_object_id          = azuread_service_principal.argocd.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["openid", "profile", "email", "User.Read"]
}

resource "azuread_app_role_assignment" "argocd" {
  app_role_id         = "00000000-0000-0000-0000-000000000000" # Default app role
  principal_object_id = azuread_group.argocd_admins.object_id
  resource_object_id  = azuread_service_principal.argocd.object_id
}


resource "azurerm_user_assigned_identity" "argocd_controller" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "argocd-application-controller"
}

resource "azurerm_federated_identity_credential" "argocd_controller" {
  user_assigned_identity_id = azurerm_user_assigned_identity.argocd_controller.id
  name                      = "argocd-application-controller"
  issuer                    = azurerm_kubernetes_cluster.control.oidc_issuer_url
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:argocd:argocd-application-controller"
}

resource "azurerm_role_assignment" "argocd_controller_worker" {
  principal_id                     = azurerm_user_assigned_identity.argocd_controller.principal_id
  scope                            = azapi_resource.aks_worker.id
  role_definition_name             = "Azure Kubernetes Service RBAC Cluster Admin"
  skip_service_principal_aad_check = true
}

locals {
  oidc_config = <<EOT
name: Microsoft Entra ID
issuer: https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0
clientID: ${azuread_application.argocd.client_id}
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
g, "${azuread_group.argocd_admins.object_id}", role:admin
g, "${azuread_group.argocd_users.object_id}", role:user
EOT
}

resource "azurerm_kubernetes_cluster_extension" "argocd" {
  name           = "argocd"
  cluster_id     = azurerm_kubernetes_cluster.control.id
  extension_type = "Microsoft.ArgoCD"
  release_train  = "Stable"

  configuration_settings = {
    "azure.workloadIdentity.enabled"                                                   = "true"
    "azure.workloadIdentity.clientId"                                                  = azuread_application.argocd.client_id
    "azure.workloadIdentity.entraSSOClientId"                                          = azuread_application.argocd.client_id
    "redis-ha.enabled"                                                                 = "false"
    "global.domain"                                                                    = "argocd.${azurerm_dns_zone.example.name}"
    "configs.cm.admin\\.enabled"                                                       = "false"
    "configs.cm.oidc\\.config"                                                         = local.oidc_config
    "configs.rbac.policy\\.csv"                                                        = local.policy_csv
    "configs.params.server\\.insecure"                                                 = "true"
    "dex.enabled"                                                                      = "false"
    "server.podLabels.azure\\.workload\\.identity/use"                                 = "true"
    "server.serviceAccount.annotations.azure\\.workload\\.identity/client-id"          = "${azuread_application.argocd.client_id}"
    "controller.serviceAccount.annotations.azure\\.workload\\.identity/client-id"      = azurerm_user_assigned_identity.argocd_controller.client_id
    "controller.env[0].name"                                                           = "AZURE_CLIENT_ID"
    "controller.env[0].value"                                                          = azurerm_user_assigned_identity.argocd_controller.client_id
    "controller.env[1].name"                                                           = "AZURE_TENANT_ID"
    "controller.env[1].value"                                                          = data.azurerm_client_config.current.tenant_id
    "controller.env[2].name"                                                           = "AZURE_FEDERATED_TOKEN_FILE"
    "controller.env[2].value"                                                          = "/var/run/secrets/azure/tokens/azure-identity-token"
    "controller.env[3].name"                                                           = "AZURE_AUTHORITY_HOST"
    "controller.env[3].value"                                                          = "https://login.microsoftonline.com/"
    "controller.volumes[0].name"                                                       = "azure-identity-token"
    "controller.volumes[0].projected.sources[0].serviceAccountToken.audience"          = "api://AzureADTokenExchange"
    "controller.volumes[0].projected.sources[0].serviceAccountToken.expirationSeconds" = "3600"
    "controller.volumes[0].projected.sources[0].serviceAccountToken.path"              = "azure-identity-token"
    "controller.volumeMounts[0].name"                                                  = "azure-identity-token"
    "controller.volumeMounts[0].mountPath"                                             = "/var/run/secrets/azure/tokens"
  }
}


resource "local_file" "argocd" {
  filename = "kubernetes/argo-cd.yaml"
  content = templatefile("argo-cd.tmpl",
    {
      DNS_ZONE_NAME = azurerm_dns_zone.example.name
    }
  )
}

resource "local_file" "argo_worker_cluster" {
  filename = "kubernetes/argo-worker-cluster.yaml"
  content = templatefile("argo-worker-cluster.tmpl", {
    WORKER_SERVER   = "https://${azapi_resource.aks_worker.output.properties.fqdn}:443"
    WORKER_CA       = local.worker_cluster_ca_certificate
    ARGO_CLIENT_ID  = azurerm_user_assigned_identity.argocd_controller.client_id
    AZURE_TENANT_ID = data.azurerm_client_config.current.tenant_id
  })
}