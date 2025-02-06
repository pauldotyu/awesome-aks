output "microsoft_issuer_url" {
  value = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0"
}

output "microsoft_client_id" {
  value = azuread_application.example.client_id
}

output "microsoft_group_id" {
  value = azuread_group.example.object_id
}

output "okta_client_id" {
  value = okta_app_oauth.example.client_id
}

output "okta_issuer_url" {
  value = okta_auth_server.example.issuer
}

output "okta_group_name" {
  value = okta_group.example.name
}
