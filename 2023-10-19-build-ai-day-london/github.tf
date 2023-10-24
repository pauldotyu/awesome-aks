# resource "azurerm_user_assigned_identity" "gh_action" {
#   location            = azurerm_resource_group.example.location
#   name                = "gh-${local.name}"
#   resource_group_name = azurerm_resource_group.example.name
# }

# resource "azurerm_federated_identity_credential" "gh_action" {
#   name                = "gh-${local.name}"
#   resource_group_name = azurerm_resource_group.example.name
#   parent_id           = azurerm_user_assigned_identity.gh_action.id
#   audience            = ["api://AzureADTokenExchange"]
#   issuer              = "https://token.actions.githubusercontent.com"
#   subject             = "repo:${var.gh_organization}/${var.repo_name}:ref:refs/heads/${var.repo_branch}"
# }

# resource "github_actions_secret" "gh_action_client_id" {
#   repository      = var.repo_name
#   secret_name     = "AZURE_CLIENT_ID"
#   plaintext_value = azurerm_user_assigned_identity.example.client_id
# }

# resource "github_actions_secret" "gh_action_tenant_id" {
#   repository      = var.repo_name
#   secret_name     = "AZURE_TENANT_ID"
#   plaintext_value = data.azurerm_client_config.current.tenant_id
# }

# resource "github_actions_secret" "gh_action_subscription_id" {
#   repository      = var.repo_name
#   secret_name     = "AZURE_SUBSCRIPTION_ID"
#   plaintext_value = data.azurerm_subscription.current.subscription_id
# }
