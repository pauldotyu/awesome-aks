output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azapi_resource.aks.name
}

output "aks_json_output" {
  value = jsondecode(azapi_resource.aks.output)
}