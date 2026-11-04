resource "azurerm_dns_zone" "example" {
  name                = var.dns_zone_name
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_dns_zone" "apps" {
  name                = "apps.${azurerm_dns_zone.example.name}"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_dns_ns_record" "apps_delegation" {
  name                = "apps"
  zone_name           = azurerm_dns_zone.example.name
  resource_group_name = azurerm_resource_group.example.name
  ttl                 = 300
  records             = azurerm_dns_zone.apps.name_servers
}