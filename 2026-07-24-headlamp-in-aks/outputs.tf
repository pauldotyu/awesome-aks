output "rg_name" {
  description = "The name of the Resource Group"
  value       = azurerm_resource_group.example.name
}

output "aks_name" {
  description = "The name of the AKS Cluster"
  value       = azurerm_kubernetes_cluster.example.name
}

output "headlamp_app_tenant_id" {
  description = "The Tenant ID of the Microsoft Entra Application"
  value       = data.azuread_client_config.current.tenant_id
}

output "headlamp_app_client_id" {
  description = "The Application (client) ID of the Microsoft Entra Application"
  value       = azuread_application.headlamp.client_id
}

output "headlamp_admin_object_id" {
  description = "The Object ID of the Microsoft Entra Group with admin access to Headlamp"
  value       = data.azuread_client_config.current.object_id
}

output "dns_zone_name" {
  description = "The DNS zone name created for Headlamp ingress."
  value       = azurerm_dns_zone.example.name
}

output "dns_zone_nameservers" {
  description = "The DNS zone nameservers."
  value       = azurerm_dns_zone.example.name_servers
}

output "user_email" {
  description = "The email of the current Microsoft Entra user."
  value       = data.azuread_user.current.mail
}

output "subscription_id" {
  description = "The Subscription ID where resources are deployed."
  value       = data.azurerm_client_config.current.subscription_id
}

output "cert_manager_identity_client_id" {
  description = "The Client ID of the User Assigned Identity for Cert-Manager."
  value       = azurerm_user_assigned_identity.cert_manager.client_id
}