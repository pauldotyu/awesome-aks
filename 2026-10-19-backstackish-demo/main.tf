data "azuread_client_config" "current" {}
data "azurerm_client_config" "current" {}
data "azuread_application_published_app_ids" "well_known" {}
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

locals {
  msgraph_oauth2_permission_scope_ids = {
    for scope in data.azuread_service_principal.msgraph.oauth2_permission_scopes : scope.value => scope.id
  }
  # Application permissions used by the catalog msgraph provider to import users and groups
  msgraph_app_roles = ["User.Read.All", "GroupMember.Read.All", "Group.Read.All"]

  random_name        = random_pet.example.id
  random_unique_name = "${random_pet.example.id}${random_integer.example.result}"
  aks_control_name   = "aks-${local.random_name}-control"
  aks_shared_name    = "aks-${local.random_name}-worker"
}

resource "random_pet" "example" {
  length    = 2
  separator = ""
}

resource "random_integer" "example" {
  min = 10
  max = 99
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.random_name}"
  location = var.location
  tags     = var.tags
}

