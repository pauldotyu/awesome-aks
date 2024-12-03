output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.example.name
}

output "acr_name" {
  value = azurerm_container_registry.example.name
}

output "repository" {
  value = var.registry_repository_name
}

