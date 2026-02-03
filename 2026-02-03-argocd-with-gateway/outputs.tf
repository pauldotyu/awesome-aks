output "rg_name" {
  description = "The name of the Resource Group"
  value       = azurerm_resource_group.example.name
}

output "aks_name" {
  description = "The name of the AKS Cluster"
  value       = azurerm_kubernetes_cluster.example.name
}

output "argocd_app_tenant_id" {
  description = "The Tenant ID of the Azure AD Application"
  value       = data.azuread_client_config.current.tenant_id
}

output "argocd_app_client_id" {
  description = "The Application (client) ID of the Azure AD Application"
  value       = azuread_application.example.client_id
}

output "argocd_admin_object_id" {
  description = "The Object ID of the Azure AD Group with admin access to ArgoCD"
  value       = data.azuread_client_config.current.object_id
}

output "dns_zone_name" {
  description = "The DNS zone name created for Argo CD ingress."
  value       = azurerm_dns_zone.example.name
}

output "dns_zone_nameservers" {
  description = "The DNS zone nameservers."
  value       = azurerm_dns_zone.example.name_servers
}

output "user_email" {
  description = "The email of the current Azure AD user."
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