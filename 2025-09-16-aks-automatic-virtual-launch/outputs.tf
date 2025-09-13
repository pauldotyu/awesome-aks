output "rg_name" {
  description = "The name of the Resource Group."
  value       = azapi_resource.rg.name
}

output "aks_name" {
  description = "The name of the AKS cluster."
  value       = azapi_resource.aks.name
}

output "dns_zone_name_servers" {
  description = "The name servers of the DNS zone."
  value       = azapi_resource.dns.output.properties.nameServers
}