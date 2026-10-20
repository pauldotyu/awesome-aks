output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.control.name
}

output "dns_zone_name" {
  value = azurerm_dns_zone.example.name
}

output "dns_name_servers" {
  value = azurerm_dns_zone.example.name_servers
}