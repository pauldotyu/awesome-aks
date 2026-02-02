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

output "admin_group_object_id" {
  description = "The Object ID of the Azure AD Group with admin access to ArgoCD"
  value       = data.azuread_group.example.object_id
}
