// https://learn.microsoft.com/azure/templates/microsoft.containerregistry/registries?pivots=deployment-language-terraform
resource "azapi_resource" "acr" {
  type      = "Microsoft.ContainerRegistry/registries@2025-05-01-preview"
  name      = "acr${local.random_name}"
  parent_id = azapi_resource.rg.id
  location  = azapi_resource.rg.location
  tags      = var.tags
  body = {
    sku = {
      name = "Basic"
    }
    properties = {}
  }
}
