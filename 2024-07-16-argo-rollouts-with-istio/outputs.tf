output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.example.name
}

output "oai_gpt_endpoint" {
  value = azurerm_cognitive_account.example.endpoint
}

output "oai_gpt_deployment_name" {
  value = var.gpt4_deployment_name
}

output "oai_dalle_endpoint" {
  value = azurerm_cognitive_account.example.endpoint
}

output "oai_dalle_deployment_name" {
  value = var.dalle_deployment_name
}

output "oai_dalle_api_version" {
  value = var.dalle_openai_api_version
}

output "oai_identity_client_id" {
  value = azurerm_user_assigned_identity.oai.client_id
}

output "amg_name" {
  value = azurerm_dashboard_grafana.example.name
}