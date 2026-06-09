output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.example.name
}

output "lfs_name" {
  value = azurerm_managed_lustre_file_system.example.name
}

output "lfs_mgs_address" {
  value = azurerm_managed_lustre_file_system.example.mgs_address
}