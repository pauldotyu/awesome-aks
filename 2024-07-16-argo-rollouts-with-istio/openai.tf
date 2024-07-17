resource "azurerm_cognitive_account" "example" {
  resource_group_name   = azurerm_resource_group.example.name
  location              = var.ai_location
  name                  = "oai-${local.random_name}"
  custom_subdomain_name = "oai-${local.random_name}"
  kind                  = "OpenAI"
  sku_name              = "S0"
  local_auth_enabled    = false
}

resource "azurerm_cognitive_deployment" "gpt4" {
  count                = var.deploy_gpt4 ? 1 : 0
  cognitive_account_id = azurerm_cognitive_account.example.id
  name                 = var.gpt4_deployment_name

  model {
    name    = "gpt-4o"
    format  = "OpenAI"
    version = "2024-05-13"
  }

  scale {
    type = "Standard"
  }
}

resource "azurerm_cognitive_deployment" "dalle" {
  count                = var.deploy_dalle ? 1 : 0
  cognitive_account_id = azurerm_cognitive_account.example.id
  name                 = var.dalle_deployment_name

  model {
    name    = "dall-e-3"
    format  = "OpenAI"
    version = "3.0"
  }

  scale {
    type = "Standard"
  }
}

resource "azurerm_user_assigned_identity" "oai" {
  resource_group_name = azurerm_resource_group.example.name
  location            = var.ai_location
  name                = "oai-${local.random_name}-identity"
}

resource "azurerm_federated_identity_credential" "oai" {
  resource_group_name = azurerm_resource_group.example.name
  parent_id           = azurerm_user_assigned_identity.oai.id
  name                = "oai-${local.random_name}"
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  audience            = ["api://AzureADTokenExchange"]
  subject             = "system:serviceaccount:${var.k8s_namespace}:ai-service-account"
}

resource "azurerm_role_assignment" "oai_rbac_mi" {
  scope                = azurerm_cognitive_account.example.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.oai.principal_id
}

resource "azurerm_role_assignment" "oai_rbac_me" {
  scope                = azurerm_cognitive_account.example.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = data.azurerm_client_config.current.object_id
}

