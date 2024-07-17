resource "azurerm_app_configuration" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "ac-${local.random_name}"
  sku                 = "standard"
  local_auth_enabled  = false

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_app_configuration_key" "example_config_use_aoai" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "USE_AZURE_OPENAI"
  value                  = "True"

  depends_on = [
    azurerm_role_assignment.ac_rbac_me,
  ]
}

resource "azurerm_app_configuration_key" "example_config_use_aad" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "USE_AZURE_AD"
  value                  = "True"

  depends_on = [
    azurerm_role_assignment.ac_rbac_me
  ]
}

resource "azurerm_app_configuration_key" "example_config_model_name" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "AZURE_OPENAI_DEPLOYMENT_NAME"
  value                  = var.gpt4_deployment_name

  depends_on = [
    azurerm_role_assignment.ac_rbac_me
  ]
}

resource "azurerm_app_configuration_key" "example_config_endpoint" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "AZURE_OPENAI_ENDPOINT"
  value                  = azurerm_cognitive_account.example.endpoint

  depends_on = [
    azurerm_role_assignment.ac_rbac_me
  ]
}

resource "azurerm_user_assigned_identity" "ac" {
  resource_group_name = azurerm_resource_group.example.name
  location            = var.location
  name                = "ac-${local.random_name}-identity"
}

resource "azurerm_federated_identity_credential" "ac" {
  resource_group_name = azurerm_resource_group.example.name
  parent_id           = azurerm_user_assigned_identity.ac.id
  name                = "ac-${local.random_name}"
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  audience            = ["api://AzureADTokenExchange"]
  subject             = "system:serviceaccount:azappconfig-system:az-appconfig-k8s-provider"
}

// Give the VMSS identity the ability to read from the App Configuration instance
resource "azurerm_role_assignment" "ac_rbac_mi" {
  scope                = azurerm_app_configuration.example.id
  role_definition_name = "App Configuration Data Reader"
  principal_id         = azurerm_user_assigned_identity.ac.principal_id
}

// Give yourself the ability to write key-value pairs to the App Configuration instance
resource "azurerm_role_assignment" "ac_rbac_me" {
  scope                = azurerm_app_configuration.example.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}
