terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.1.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.2"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.3"
    }
  }
}

data "azuread_client_config" "current" {}

resource "azuread_group" "example" {
  display_name     = "K8s Cluster Admins"
  security_enabled = true
}

resource "azuread_group_member" "example" {
  group_object_id  = azuread_group.example.object_id
  member_object_id = data.azuread_client_config.current.object_id
}

resource "random_integer" "example" {
  min = 10
  max = 99
}

resource "azuread_application" "example" {
  display_name                   = "example${random_integer.example.result}"
  owners                         = [data.azuread_client_config.current.object_id]
  group_membership_claims        = ["SecurityGroup"]
  fallback_public_client_enabled = true

  optional_claims {
    access_token {
      name = "groups"
    }
    id_token {
      name = "email"
    }
  }

  public_client {
    redirect_uris = ["http://localhost:8000"]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

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

resource "local_file" "auth_config" {
  filename = "./structured-auth.yaml"
  content = templatefile("structured-auth.tmpl",
    {
      TENANT_ID = data.azuread_client_config.current.tenant_id
      CLIENT_ID = azuread_application.example.client_id
    }
  )
}

output "tenant_id" {
  value = data.azuread_client_config.current.tenant_id
}

output "client_id" {
  value = azuread_application.example.client_id
}

output "group_id" {
  value = azuread_group.example.object_id
}
