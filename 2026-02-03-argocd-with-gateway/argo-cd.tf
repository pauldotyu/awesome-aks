data "azuread_application_published_app_ids" "well_known" {}
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

locals {
  msgraph_oauth2_permission_scope_ids = {
    for scope in data.azuread_service_principal.msgraph.oauth2_permission_scopes :
    scope.value => scope.id
  }
}

resource "azuread_application" "example" {
  display_name            = "app-argocd-${random_integer.example.result}"
  owners                  = [data.azuread_client_config.current.object_id]
  sign_in_audience        = "AzureADMyOrg"
  group_membership_claims = ["ApplicationGroup"]

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
    access_token {
      name                  = "groups"
      essential             = true
      additional_properties = ["emit_as_roles"]
    }

    id_token {
      name                  = "groups"
      essential             = true
      additional_properties = ["emit_as_roles"]
    }
  }
}

resource "azuread_application_federated_identity_credential" "example" {
  application_id = azuread_application.example.id
  display_name   = azuread_application.example.display_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azurerm_kubernetes_cluster.example.oidc_issuer_url
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

resource "azuread_app_role_assignment" "example" {
  app_role_id         = "00000000-0000-0000-0000-000000000000" # Default app role
  principal_object_id = data.azuread_client_config.current.object_id
  resource_object_id  = azuread_service_principal.example.object_id
}

resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.3.7"
  namespace        = "argocd"
  create_namespace = true

  values = [<<-YAML
global:
  domain: argocd.${azurerm_dns_zone.example.name}
configs:
  cm:
    admin.enabled: false
    oidc.config: |
      name: Microsoft Entra ID
      issuer: https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0
      clientID: ${azuread_application.example.client_id}
      azure:
        useWorkloadIdentity: true
      requestedIDTokenClaims:
        groups:
          essential: true
          value: "ApplicationGroup"
      requestedScopes:
        - openid
        - profile
        - email
    rbac:
      policy.csv: |
        p, role:org-admin, applications, *, */*, allow
        p, role:org-admin, clusters, get, *, allow
        p, role:org-admin, repositories, get, *, allow
        p, role:org-admin, repositories, create, *, allow
        p, role:org-admin, repositories, update, *, allow
        p, role:org-admin, repositories, delete, *, allow
        g, "${data.azuread_client_config.current.object_id}", role:org-admin
  params:
    server.insecure: "true"
server:
  podLabels:
    azure.workload.identity/use: "true"
  serviceAccount:
    annotations:
      azure.workload.identity/client-id: ${azuread_application.example.client_id}
YAML
  ]
}
