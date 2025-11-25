output "rg_name" {
  description = "The name of the Resource Group"
  value       = azurerm_resource_group.example.name
}

output "aks_name" {
  description = "The name of the AKS Cluster"
  value       = module.avm-res-containerservice-managedcluster.name
}

output "aks_props" {
  description = "The properties of the AKS Cluster"
  value       = module.avm-res-containerservice-managedcluster
  sensitive   = true
}