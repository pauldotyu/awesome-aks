output "rg_name" {
  description = "The name of the Resource Group"
  value       = azurerm_resource_group.example.name
}

output "aks_name" {
  description = "The name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.example.name
}

output "admin_password" {
  description = "The admin password for the Windows VM"
  value       = random_password.example.result
  sensitive   = true
}
