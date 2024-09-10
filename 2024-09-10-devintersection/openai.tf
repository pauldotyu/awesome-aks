resource "azurerm_cognitive_account" "example" {
  resource_group_name   = azurerm_resource_group.example.name
  location              = var.location
  name                  = "oai-${local.random_name}"
  custom_subdomain_name = "oai-${local.random_name}"
  kind                  = "OpenAI"
  sku_name              = "S0"
  local_auth_enabled    = false
}

resource "azurerm_cognitive_deployment" "gpt" {
  cognitive_account_id = azurerm_cognitive_account.example.id
  name                 = "gpt-4o"

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-05-13"
  }

  sku {
    name     = "Standard"
    capacity = 8
  }
}

# resource "azurerm_cognitive_deployment" "dalle" {
#   cognitive_account_id = azurerm_cognitive_account.example.id
#   name                 = "dall-e-3"

#   model {
#     format  = "OpenAI"
#     name    = "dall-e-3"
#     version = "3.0"
#   }

#   sku {
#     name     = "Standard"
#     capacity = 1
#   }
# }

resource "azurerm_user_assigned_identity" "oai" {
  resource_group_name = azurerm_resource_group.example.name
  location            = var.location
  name                = "oai-${local.random_name}-identity"
}

# Don't deploy these below as AKS Service Connector will take care of it

# resource "azurerm_federated_identity_credential" "oai" {
#   resource_group_name = azurerm_resource_group.example.name
#   parent_id           = azurerm_user_assigned_identity.oai.id
#   name                = "${azurerm_cognitive_account.example.name}-k8s"
#   issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
#   audience            = ["api://AzureADTokenExchange"]
#   subject             = "system:serviceaccount:pets:ai-service-account"
# }

# resource "azurerm_role_assignment" "oai_rbac_mi" {
#   scope                = azurerm_cognitive_account.example.id
#   role_definition_name = "Cognitive Services OpenAI User"
#   principal_id         = azurerm_user_assigned_identity.oai.principal_id
# }

# resource "azurerm_role_assignment" "oai_rbac_me" {
#   scope                = azurerm_cognitive_account.example.id
#   role_definition_name = "Cognitive Services OpenAI User"
#   principal_id         = data.azurerm_client_config.current.object_id
# }