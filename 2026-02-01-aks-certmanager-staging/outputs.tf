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

output "dns_zone_nameservers" {
  description = "The nameservers of the DNS Zone"
  value       = azurerm_dns_zone.example.name_servers
}

output "dns_zone_subdomain" {
  description = "The CNAME record created in the DNS Zone"
  value       = azurerm_dns_cname_record.example.name
}

output "lb_dns_label" {
  description = "The DNS label of the AKS Load Balancer"
  value       = local.lb_dns_label
}

output "mi_client_id" {
  description = "The Client ID of the User Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.example.client_id
}