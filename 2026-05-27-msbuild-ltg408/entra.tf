data "azuread_application_published_app_ids" "well_known" {}
data "azuread_client_config" "current" {}
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

locals {
  msgraph_scopes = { for s in data.azuread_service_principal.msgraph.oauth2_permission_scopes : s.value => s }
}

resource "azuread_application" "example" {
  display_name            = "myargocdapp"
  owners                  = [data.azuread_client_config.current.object_id]
  sign_in_audience        = "AzureADMyOrg"
  group_membership_claims = ["ApplicationGroup"]

  web {
    redirect_uris = [
      "https://localhost:9000/auth/callback"
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
      id   = local.msgraph_scopes["openid"].id
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_scopes["profile"].id
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_scopes["email"].id
      type = "Scope"
    }

    resource_access {
      id   = local.msgraph_scopes["User.Read"].id
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
  display_name = "CloudNative" # Update this to match your group name
}

resource "azuread_app_role_assignment" "example" {
  app_role_id         = "00000000-0000-0000-0000-000000000000" # Default app role
  principal_object_id = data.azuread_group.example.object_id
  resource_object_id  = azuread_service_principal.example.object_id
}