output "aks_name" {
  value = azurerm_kubernetes_cluster.example.name
}

output "rg_name" {
  value = azurerm_resource_group.example.name
}