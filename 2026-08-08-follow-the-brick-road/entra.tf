data "azuread_application_published_app_ids" "well_known" {}
data "azuread_client_config" "current" {}
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

locals {
  msgraph_scopes = {
    for s in data.azuread_service_principal.msgraph.oauth2_permission_scopes :
    s.value => s
  }
  msgraph_oauth2_permission_scope_ids = {
    for scope in data.azuread_service_principal.msgraph.oauth2_permission_scopes :
    scope.value => scope.id
  }
}