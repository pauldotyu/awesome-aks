// https://learn.microsoft.com/azure/templates/microsoft.monitor/accounts?pivots=deployment-language-terraform
resource "azapi_resource" "prom" {
  type      = "Microsoft.Monitor/accounts@2025-05-03-preview"
  name      = "prom-${local.random_name}"
  parent_id = azapi_resource.rg.id
  location  = azapi_resource.rg.location
  tags      = var.tags
  body = {
    properties = {}
  }
}
