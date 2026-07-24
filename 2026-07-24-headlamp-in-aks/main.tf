data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}
data "azuread_user" "current" {
  object_id = data.azuread_client_config.current.object_id
}
data "azuread_application_published_app_ids" "well_known" {}
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}
data "azuread_service_principal" "aks" {
  client_id = data.azuread_application_published_app_ids.well_known.result["AzureKubernetesServiceAadServer"]
}

locals {
  msgraph_oauth2_permission_scope_ids = {
    for scope in data.azuread_service_principal.msgraph.oauth2_permission_scopes :
    scope.value => scope.id
  }
  aks_oauth2_permission_scope_ids = {
    for scope in data.azuread_service_principal.aks.oauth2_permission_scopes :
    scope.value => scope.id
  }
}

resource "random_integer" "example" {
  min = 10
  max = 99
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.random_name}"
  location = var.location
}
