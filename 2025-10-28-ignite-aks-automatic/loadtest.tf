// https://learn.microsoft.com/azure/templates/microsoft.loadtestservice/loadtests?pivots=deployment-language-terraform
resource "azapi_resource" "lt" {
  type      = "Microsoft.LoadTestService/loadTests@2024-12-01-preview"
  name      = "lt-${local.random_name}"
  parent_id = azapi_resource.rg.id
  location  = var.lt_location
  tags      = var.tags
  body = {
    properties = {}
  }
}