// https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/accounts?pivots=deployment-language-terraform
resource "azapi_resource" "oai" {
  type                      = "Microsoft.CognitiveServices/accounts@2025-07-01-preview"
  name                      = "oai-${local.random_name}"
  parent_id                 = azapi_resource.rg.id
  location                  = var.ai_location
  tags                      = var.tags
  schema_validation_enabled = false
  body = {
    kind = "OpenAI"
    properties = {
      customSubDomainName = "oai-${local.random_name}"
      publicNetworkAccess = "Enabled"
    }
    sku = {
      name = "S0"
    }
  }
}

// https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/accounts/deployments?pivots=deployment-language-terraform
resource "azapi_resource" "oai_gpt_5_mini" {
  type                      = "Microsoft.CognitiveServices/accounts/deployments@2025-07-01-preview"
  name                      = "gpt-5-mini"
  parent_id                 = azapi_resource.oai.id
  tags                      = var.tags
  schema_validation_enabled = false
  body = {
    properties = {
      model = {
        format  = "OpenAI"
        name    = "gpt-5-mini"
        version = "2025-08-07"
      }
    }
    sku = {
      capacity = 250
      name     = "GlobalStandard"
    }
  }
}