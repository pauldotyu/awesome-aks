// https://learn.microsoft.com/azure/templates/microsoft.loadtestservice/playwrightworkspaces?pivots=deployment-language-terraform
resource "azapi_resource" "pw" {
  type                      = "Microsoft.LoadTestService/playwrightWorkspaces@2025-09-01"
  name                      = "pw-${local.random_name}"
  parent_id                 = azapi_resource.rg.id
  location                  = var.pw_location
  tags                      = var.tags
  schema_validation_enabled = false
  body = {
    properties = {
      localAuth        = "Disabled"
      regionalAffinity = "Enabled"
    }
  }
}