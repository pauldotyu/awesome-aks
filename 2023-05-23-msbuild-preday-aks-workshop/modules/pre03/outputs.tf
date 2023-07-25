output "users" {
  value = flatten([azuread_user.pre03.*.user_principal_name])
}

output "resource_groups" {
  value = flatten([azurerm_resource_group.pre03.*.name])
}

output "aks_clusters" {
  value = flatten([azurerm_kubernetes_cluster.pre03.*.name])
}