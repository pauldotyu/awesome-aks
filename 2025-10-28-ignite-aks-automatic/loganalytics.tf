// https://learn.microsoft.com/azure/templates/microsoft.operationalinsights/workspaces?pivots=deployment-language-terraform
resource "azapi_resource" "law" {
  type      = "Microsoft.OperationalInsights/workspaces@2025-02-01"
  name      = "law-${local.random_name}"
  parent_id = azapi_resource.rg.id
  location  = azapi_resource.rg.location
  tags      = var.tags
  body = {
    properties = {
      sku = {
        name = "PerGB2018"
      }
      retentionInDays = 30
    }
  }
}