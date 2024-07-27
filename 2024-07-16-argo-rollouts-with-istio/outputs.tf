output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.example.name
}

output "ac_id" {
  value = azurerm_app_configuration.example.id
}

output "ac_endpoint" {
  value = azurerm_app_configuration.example.endpoint
}

output "oai_identity_client_id" {
  value = azurerm_user_assigned_identity.oai.client_id
}

output "amg_name" {
  value = azurerm_dashboard_grafana.example.name
}