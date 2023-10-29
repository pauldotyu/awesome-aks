output "aks_name" {
  value = azurerm_kubernetes_cluster.example.name
}

output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "store_front_fqdn" {
  value = data.external.store_front_fqdn.result.value
}

output "store_admin_fqdn" {
  value = data.external.store_admin_fqdn.result.value
}