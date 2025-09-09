// https://learn.microsoft.com/azure/templates/microsoft.keyvault/vaults?pivots=deployment-language-terraform
resource "azapi_resource" "kv" {
  type      = "Microsoft.KeyVault/vaults@2024-12-01-preview"
  name      = "kv-${local.random_name}"
  parent_id = azapi_resource.rg.id
  location  = azapi_resource.rg.location
  tags      = var.tags
  body = {
    properties = {
      enableRbacAuthorization = true
      enableSoftDelete        = true
      publicNetworkAccess     = "Enabled"
      sku = {
        family = "A"
        name   = "standard"
      }
      softDeleteRetentionInDays = 90
      tenantId                  = data.azurerm_client_config.current.tenant_id
    }
  }
}

resource "random_uuid" "kv_administrator" {}
resource "azapi_resource" "kv_administrator" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.kv_administrator.result
  parent_id = azapi_resource.kv.id
  body = {
    properties = {
      principalId      = data.azurerm_client_config.current.object_id
      roleDefinitionId = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/00482a5a-887f-4fb3-b363-3b7fe8e74483" // Key Vault Administrator
      principalType    = "User"
    }
  }
}
