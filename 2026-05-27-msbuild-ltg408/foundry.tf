resource "azurerm_cognitive_account" "example" {
  resource_group_name   = azurerm_resource_group.example.name
  location              = azurerm_resource_group.example.location
  name                  = "mf-${local.random_name}"
  custom_subdomain_name = "mf-${local.random_name}"
  kind                  = "AIServices"
  sku_name              = "S0"
  local_auth_enabled    = true
}

resource "azurerm_cognitive_deployment" "example" {
  cognitive_account_id = azurerm_cognitive_account.example.id
  name                 = "gpt-5.4-mini"
  rai_policy_name      = "Microsoft.DefaultV2"

  model {
    format  = "OpenAI"
    name    = "gpt-5.4-mini"
    version = "2026-03-17"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10000
  }
}

resource "azurerm_cognitive_deployment" "image" {
  cognitive_account_id = azurerm_cognitive_account.example.id
  name                 = "gpt-image-2"
  rai_policy_name      = "Microsoft.DefaultV2"

  model {
    format  = "OpenAI"
    name    = "gpt-image-2"
    version = "2026-04-21"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 5
  }
}

resource "azurerm_role_assignment" "me" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Cognitive Services OpenAI User"
  scope                = azurerm_cognitive_account.example.id
}

resource "azurerm_user_assigned_identity" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "mi-${local.random_name}"
}

resource "azurerm_role_assignment" "mi" {
  principal_id         = azurerm_user_assigned_identity.example.principal_id
  role_definition_name = "Cognitive Services OpenAI User"
  scope                = azurerm_cognitive_account.example.id
}

resource "azurerm_federated_identity_credential" "aks-agent" {
  user_assigned_identity_id = azurerm_user_assigned_identity.example.id
  name                      = "aks-agent"
  issuer                    = azapi_resource.aks.output.properties.oidcIssuerProfile.issuerURL
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:aks-agent-system:aks-agent-sa"
}

resource "azurerm_federated_identity_credential" "contoso-air" {
  user_assigned_identity_id = azurerm_user_assigned_identity.example.id
  name                      = "contoso-air"
  issuer                    = azapi_resource.aks.output.properties.oidcIssuerProfile.issuerURL
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:team-blue:contoso-air-sa"
}