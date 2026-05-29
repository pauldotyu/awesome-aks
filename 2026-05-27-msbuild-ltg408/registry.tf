resource "azurerm_container_registry" "example" {
  resource_group_name    = azurerm_resource_group.example.name
  location               = azurerm_resource_group.example.location
  name                   = "acr${local.random_name}"
  sku                    = "Standard"
  admin_enabled          = false
  anonymous_pull_enabled = false
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azapi_resource.aks.output.properties.identityProfile.kubeletidentity.objectId
  scope                            = azurerm_container_registry.example.id
  role_definition_name             = "AcrPull"
  skip_service_principal_aad_check = true
}