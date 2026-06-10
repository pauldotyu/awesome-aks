output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azapi_resource.aks.name
}

output "anyscale_iam_client_id" {
  value = azurerm_user_assigned_identity.example.client_id
}

output "anyscale_cloud_name" {
  value = lower(azapi_resource.anyscale_cloud.id)
}

output "anyscale_cloud_id" {
  value = split("/", azapi_resource.anyscale_cloud.output.properties.ssoUrl)[4]
}

output "anyscale_cloud_sso_url" {
  value = azapi_resource.anyscale_cloud.output.properties.ssoUrl
}

output "anyscale_cloud_resource_id" {
  value = azapi_resource.anyscale_cloud_resource.output.properties.cloudResourceId
}