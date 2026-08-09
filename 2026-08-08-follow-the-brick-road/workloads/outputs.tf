output "mi_client_id" {
  description = "The client ID for the AKS cluster's managed identity"
  value       = azurerm_user_assigned_identity.example.client_id
}

output "mf_api_base_url" {
  description = "The base URL for Microsoft Foundry API"
  value       = azurerm_cognitive_account.example.endpoint
}

output "mf_api_key" {
  description = "The API key for Microsoft Foundry"
  value       = azurerm_cognitive_account.example.primary_access_key
  sensitive   = true
}
