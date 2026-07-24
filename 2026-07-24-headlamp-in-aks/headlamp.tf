resource "azuread_application" "headlamp" {
  display_name            = "app-headlamp-${random_integer.example.result}"
  owners                  = [data.azuread_client_config.current.object_id]
  sign_in_audience        = "AzureADMyOrg"
  group_membership_claims = ["ApplicationGroup"]

  web {
    redirect_uris = [
      "https://headlamp.${azurerm_dns_zone.example.name}/oidc-callback"
    ]
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result["AzureKubernetesServiceAadServer"]

    resource_access {
      id   = local.aks_oauth2_permission_scope_ids["user.read"]
      type = "Scope"
    }
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]

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

resource "azuread_application_password" "headlamp" {
  application_id = azuread_application.headlamp.id
}

resource "local_file" "headlamp_values" {
  filename = "values.yaml"
  content = templatefile("headlamp-values.tmpl",
    {
      HEADLAMP_APP_CLIENT_ID       = azuread_application.headlamp.client_id
      HEADLAMP_APP_CLIENT_SECRET   = azuread_application_password.headlamp.value
      AZURE_TENANT_ID              = data.azurerm_client_config.current.tenant_id
      AKS_AAD_SERVER_APP_CLIENT_ID = data.azuread_service_principal.aks.client_id
    }
  )
}

resource "azuread_application_federated_identity_credential" "headlamp" {
  application_id = azuread_application.headlamp.id
  display_name   = azuread_application.headlamp.display_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject        = "system:serviceaccount:headlamp:headlamp"
}

resource "azuread_service_principal" "headlamp" {
  client_id = azuread_application.headlamp.client_id
}

resource "azuread_service_principal_delegated_permission_grant" "msgraph" {
  service_principal_object_id          = azuread_service_principal.headlamp.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["openid", "profile", "email", "User.Read"]
}

resource "azuread_service_principal_delegated_permission_grant" "aks" {
  service_principal_object_id          = azuread_service_principal.headlamp.object_id
  resource_service_principal_object_id = data.azuread_service_principal.aks.object_id
  claim_values                         = ["user.read"]
}

data "azuread_group" "example" {
  display_name = "CloudNative" # Replace with your actual group name
}

resource "azuread_app_role_assignment" "headlamp" {
  app_role_id         = "00000000-0000-0000-0000-000000000000" # Default app role
  principal_object_id = data.azuread_group.example.object_id
  resource_object_id  = azuread_service_principal.headlamp.object_id
}

resource "helm_release" "headlamp" {
  name             = "headlamp"
  repository       = "https://kubernetes-sigs.github.io/headlamp"
  chart            = "headlamp"
  version          = "0.43.0"
  namespace        = "headlamp"
  create_namespace = true

  values = [templatefile("headlamp-values.tmpl",
    {
      HEADLAMP_APP_CLIENT_ID       = azuread_application.headlamp.client_id
      HEADLAMP_APP_CLIENT_SECRET   = azuread_application_password.headlamp.value
      AZURE_TENANT_ID              = data.azurerm_client_config.current.tenant_id
      AKS_AAD_SERVER_APP_CLIENT_ID = data.azuread_service_principal.aks.client_id
    }
  )]
}