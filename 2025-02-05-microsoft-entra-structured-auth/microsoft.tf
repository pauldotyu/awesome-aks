data "azuread_client_config" "current" {}

resource "azuread_group" "example" {
  display_name     = "k8s-admins"
  security_enabled = true
}

resource "azuread_group_member" "example" {
  group_object_id  = azuread_group.example.object_id
  member_object_id = data.azuread_client_config.current.object_id
}

resource "azuread_application" "example" {
  display_name                   = "k8s-oidc"
  owners                         = [data.azuread_client_config.current.object_id]
  group_membership_claims        = ["SecurityGroup"]
  fallback_public_client_enabled = true

  optional_claims {
    access_token {
      name = "groups"
    }

    id_token {
      name = "groups"
    }

    saml2_token {
      name = "groups"
    }
  }

  public_client {
    redirect_uris = ["http://localhost:8000"]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" // Microsoft Graph

    resource_access {
      id   = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0" // email
      type = "Scope"
    }

    resource_access {
      id   = "14dad69e-099b-42c9-810b-d002981feec1" // profile
      type = "Scope"
    }

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" // User.Read
      type = "Scope"
    }
  }
}
