output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.example.name
}

output "acr_login_server" {
  value = azurerm_container_registry.example.login_server
}

output "acr_name" {
  value = azurerm_container_registry.example.name
}

output "oai_key" {
  value     = azurerm_cognitive_account.example.primary_access_key
  sensitive = true
}