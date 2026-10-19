# ---------------------------------------------------------------------------
# Entra ID identity model
#
#   A. openchoreo-api                 - the API that issues/receives tokens
#      (application identifier uri api://openchoreo-api, OpenChoreo.Access role)
#   B. openchoreo-backstage           - public-confidential web client for sign-in
#   C. openchoreo-backstage-service   - confidential client for client-credentials
#
# Authorization model (see OpenChoreo values):
#   * users  are authorized by the `groups` JWT claim      -> platform-engineer
#   * services are authorized by the `azp` JWT claim        -> backstage-catalog-reader
# The group object id used for user authorization is obtained by looking up the
# configured Entra group and assigning it to the openchoreo-api enterprise
# application, which populates the `ApplicationGroup` group-membership claim.
# ---------------------------------------------------------------------------

# Stable UUID for the OpenChoreo.Access application role. It is referenced by
# both app-role assignments so the role can be declared and assigned atomically.
resource "random_uuid" "openchoreo_access_role" {}

# Platform engineer Entra group. Members are granted the control plane through
# the access token's `groups` claim.
data "azuread_group" "platform_engineer" {
  display_name = var.platform_engineer_group_display_name
}

# ---------------------------------------------------------------------------
# A. openchoreo-api
# ---------------------------------------------------------------------------

resource "azuread_application" "openchoreo_api" {
  display_name                   = "openchoreo-api-${local.random_suffix}"
  sign_in_audience               = "AzureADMyOrg"
  identifier_uris                = [local.openchoreo_api_app_id_uri]
  group_membership_claims        = ["ApplicationGroup"]
  fallback_public_client_enabled = false
  prevent_duplicate_names        = false
  owners                         = [data.azuread_client_config.current.object_id]

  # App role that a service/workload principal is assigned to obtain a
  # client-credentials token against the API.
  app_role {
    id                   = random_uuid.openchoreo_access_role.result
    display_name         = "OpenChoreo Access"
    value                = "OpenChoreo.Access"
    description          = "Grants a service or application token from the OpenChoreo API."
    allowed_member_types = ["Application"]
    enabled              = true
  }

  # Access-token optional claims. Entra emits these on the *access token*
  # (not only the id token) because OpenChoreo authorizes on access-token claims.
  # `groups` drives user authorization; the rest are display enrichment.
  # NOTE: the azuread provider allows a single optional_claims block, so the
  # id_token and access_token claim sets live in the same block.
  optional_claims {
    id_token {
      name      = "groups"
      essential = true
    }

    access_token {
      name      = "groups"
      essential = true
    }
    access_token {
      name      = "email"
      essential = true
    }
    access_token {
      name      = "given_name"
      essential = true
    }
    access_token {
      name      = "family_name"
      essential = true
    }
  }
}

resource "azuread_service_principal" "openchoreo_api" {
  client_id = azuread_application.openchoreo_api.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# ---------------------------------------------------------------------------
# B. openchoreo-backstage (web client for interactive sign-in)
# ---------------------------------------------------------------------------

resource "azuread_application" "openchoreo_backstage" {
  display_name                   = "openchoreo-backstage-${local.random_suffix}"
  sign_in_audience               = "AzureADMyOrg"
  fallback_public_client_enabled = false
  prevent_duplicate_names        = true
  owners                         = [data.azuread_client_config.current.object_id]

  web {
    redirect_uris = [local.console_auth_redirect_uri]
  }

  # OIDC identity scopes for the sign-in flow.
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
  }
}

resource "azuread_service_principal" "openchoreo_backstage" {
  client_id = azuread_application.openchoreo_backstage.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# Browser-client secret -> Azure Key Vault -> ESO -> backstage-secrets.
resource "azuread_application_password" "openchoreo_backstage" {
  application_id = azuread_application.openchoreo_backstage.id
  display_name   = "openchoreo-backstage-browser-secret"
  end_date       = timeadd(timestamp(), "8760h")
}

resource "azuread_service_principal_delegated_permission_grant" "backstage_msgraph" {
  service_principal_object_id          = azuread_service_principal.openchoreo_backstage.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = local.msgraph_openid_profile_email

  depends_on = [
    azuread_service_principal.openchoreo_backstage,
  ]
}

# ---------------------------------------------------------------------------
# C. openchoreo-backstage-service (client-credentials service client)
# ---------------------------------------------------------------------------

resource "azuread_application" "openchoreo_backstage_service" {
  display_name                   = "openchoreo-backstage-service-${local.random_suffix}"
  sign_in_audience               = "AzureADMyOrg"
  fallback_public_client_enabled = false
  prevent_duplicate_names        = true
  owners                         = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "openchoreo_backstage_service" {
  client_id = azuread_application.openchoreo_backstage_service.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# Service-client secret -> Azure Key Vault -> ESO -> backstage-secrets.
resource "azuread_application_password" "openchoreo_backstage_service" {
  application_id = azuread_application.openchoreo_backstage_service.id
  display_name   = "openchoreo-backstage-service-secret"
  end_date       = timeadd(timestamp(), "8760h")
}

# ---------------------------------------------------------------------------
# App-role assignments
# ---------------------------------------------------------------------------

# Grant the platform-engineer group the OpenChoreo.Access app role. This makes
# the group's object id appear in the `groups` claim of access tokens issued to
# its members (ApplicationGroup group-membership claim), which is the value the
# platform-engineer binding entitlements match on.
resource "azuread_app_role_assignment" "platform_engineer" {
  resource_object_id  = azuread_service_principal.openchoreo_api.object_id
  app_role_id         = random_uuid.openchoreo_access_role.result
  principal_object_id = data.azuread_group.platform_engineer.object_id
}

# Grant the service client the OpenChoreo.Access app role so it can mint a
# client-credentials token whose `azp` is identified for the catalog-reader
# binding.
resource "azuread_app_role_assignment" "backstage_service" {
  resource_object_id  = azuread_service_principal.openchoreo_api.object_id
  app_role_id         = random_uuid.openchoreo_access_role.result
  principal_object_id = azuread_service_principal.openchoreo_backstage_service.object_id
}

# ---------------------------------------------------------------------------
# Out-of-band Entra steps the azuread provider cannot express
#
# The azuread provider cannot declare an arbitrary delegated OAuth 2.0 scope
# ("access_as_user") or perform admin consent for a cross-app delegated grant.
# Running them via local-exec keeps them inside the dependency graph so the
# control-plane sign-in flow works end-to-end. They require an authenticated
# `az` session to the target tenant, so they are gated off by default; the exact
# commands and rationale are in the README.
# ---------------------------------------------------------------------------

resource "random_uuid" "access_as_user_scope_id" {}

resource "terraform_data" "entra_access_as_user_scope" {
  count = var.enable_azure_cli_entra_steps ? 1 : 0

  input = {
    app_id = azuread_service_principal.openchoreo_api.object_id
    scope  = random_uuid.access_as_user_scope_id.result
  }

  provisioner "local-exec" {
    # Declares the access_as_user delegated scope on openchoreo-api and admin
    # consents it tenant-wide so single-tenant users can obtain an access token
    # for api://openchoreo-api. The scope id is fixed (random_uuid) so
    # reapplication is idempotent.
    command = <<-EOT
      set -euo pipefail
      app_id=$(az ad app list --display-name "openchoreo-api-${local.random_suffix}" --query "[0].id" -o tsv)
      az ad app update \
        --id "$app_id" \
        --set "oauth2PermissionScopes=[{\"value\":\"access_as_user\",\"id\":\"${random_uuid.access_as_user_scope_id.result}\",\"isEnabled\":true,\"type\":\"Delegated\",\"description\":\"Allow the application to access OpenChoreo on behalf of a signed-in user.\",\"userConsentDisplayName\":\"Access OpenChoreo\",\"userConsentDescription\":\"Allow this application to access OpenChoreo on your behalf.\",\"administrativeConsentDisplayName\":\"Access OpenChoreo\",\"administrativeConsentDescription\":\"Allow this application to access OpenChoreo on behalf of users of the organization.\"}]"
      az ad app permission admin-consent --id "$app_id"
    EOT
  }

  depends_on = [
    azuread_service_principal.openchoreo_api,
    azuread_application.openchoreo_api,
  ]
}
