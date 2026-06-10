resource "azurerm_user_assigned_identity" "example" {
  location            = azurerm_resource_group.example.location
  name                = "${local.random_name}-operator-identity"
  resource_group_name = azurerm_resource_group.example.name

  tags = {
    "anyscale-cloud" = local.random_name
  }
}

resource "azurerm_federated_identity_credential" "example" {
  name                      = azurerm_user_assigned_identity.example.name
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azapi_resource.aks.output.properties.oidcIssuerProfile.issuerURL
  user_assigned_identity_id = azurerm_user_assigned_identity.example.id
  subject                   = "system:serviceaccount:anyscale-operator:anyscale-operator"
}

resource "azurerm_role_assignment" "blob_data_owner" {
  principal_id                     = azurerm_user_assigned_identity.example.principal_id
  role_definition_name             = "Storage Blob Data Owner"
  scope                            = azurerm_storage_account.example.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "acr_push" {
  principal_id                     = azurerm_user_assigned_identity.example.principal_id
  role_definition_name             = "AcrPush"
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "acr_task_contributor" {
  principal_id                     = azurerm_user_assigned_identity.example.principal_id
  role_definition_name             = "Container Registry Tasks Contributor" # todo: update the tool tip in the portal to reflect the new name of this role assignment
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}
