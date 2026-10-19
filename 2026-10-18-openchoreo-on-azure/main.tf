# ---------------------------------------------------------------------------
# Common data sources
# ---------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

locals {
  msgraph_oauth2_permission_scope_ids = {
    for scope in data.azuread_service_principal.msgraph.oauth2_permission_scopes :
    scope.value => scope.id
  }
}

# ---------------------------------------------------------------------------
# Random suffix + resource group
# ---------------------------------------------------------------------------

resource "random_string" "example" {
  length  = 6
  lower   = true
  numeric = false
  special = false
}

resource "azurerm_resource_group" "example" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

# Write the AKS generated kube_config to the working directory so the
# terraform_data / local-exec steps can drive kubectl and helm against the
# cluster. Ignored by git (see .gitignore).
resource "local_file" "kubeconfig" {
  filename        = local.kubeconfig_filename
  content         = azurerm_kubernetes_cluster.example.kube_config_raw
  file_permission = "0444"

  depends_on = [
    azurerm_kubernetes_cluster.example,
  ]
}
