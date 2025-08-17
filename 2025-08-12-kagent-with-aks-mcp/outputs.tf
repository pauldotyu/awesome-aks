output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.example.name
}

output "oai_endpoint" {
  value = azurerm_cognitive_account.example.endpoint
}
