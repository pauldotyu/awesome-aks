resource "azurerm_cognitive_account" "example" {
  resource_group_name   = azurerm_resource_group.example.name
  location              = azurerm_resource_group.example.location
  name                  = "mf-${local.random_name}"
  custom_subdomain_name = "mf-${local.random_name}"
  kind                  = "AIServices"
  sku_name              = "S0"
  local_auth_enabled    = true
}

resource "azurerm_cognitive_deployment" "example" {
  cognitive_account_id = azurerm_cognitive_account.example.id
  name                 = var.model_deployment.model.name
  rai_policy_name      = "Microsoft.DefaultV2"

  model {
    format  = var.model_deployment.model.format
    name    = var.model_deployment.model.name
    version = var.model_deployment.model.version
  }

  sku {
    name     = var.model_deployment.sku.name
    capacity = var.model_deployment.sku.capacity
  }
}
