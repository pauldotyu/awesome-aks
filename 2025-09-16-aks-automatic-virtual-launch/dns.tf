// https://learn.microsoft.com/azure/templates/microsoft.network/dnszones?pivots=deployment-language-terraform
resource "azapi_resource" "dns" {
  type      = "Microsoft.Network/dnsZones@2023-07-01-preview"
  name      = var.dns_zone_name
  parent_id = azapi_resource.rg.id
  location  = "global"
  tags      = var.tags
  body = {
    properties = {
      zoneType = "Public"
    }
  }
}