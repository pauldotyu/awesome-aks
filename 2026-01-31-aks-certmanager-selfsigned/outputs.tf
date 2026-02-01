output "rg_name" {
  description = "The name of the Resource Group"
  value       = azurerm_resource_group.example.name
}

output "aks_name" {
  description = "The name of the AKS Cluster"
  value       = azurerm_kubernetes_cluster.example.name
}

output "dns_zone_name" {
  description = "The name of the DNS Zone"
  value       = azurerm_dns_zone.example.name
}
