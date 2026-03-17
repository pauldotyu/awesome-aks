output "rg_name" {
  description = "The name of the Resource Group"
  value       = azurerm_resource_group.example.name
}

output "argocd_app_tenant_id" {
  description = "The Tenant ID of the Azure AD Application"
  value       = data.azuread_client_config.current.tenant_id
}

output "argocd_app_client_id" {
  description = "The Application (client) ID of the Azure AD Application"
  value       = azuread_application.example.client_id
}

output "admin_group_object_id" {
  description = "The Object ID of the Azure AD Group with admin access to Argo CD"
  value       = data.azuread_group.example.object_id
}

output "managed_identity_client_id" {
  description = "The Client ID of the Managed Identity"
  value       = azurerm_user_assigned_identity.example.client_id
}

output "connected_clusters" {
  description = "Connected cluster details keyed by environment"
  value = {
    for env, cluster in data.azapi_resource.connected_clusters : env => {
      id     = cluster.id
      name   = cluster.name
      output = cluster.output
    }
  }
}

output "fleet_name" {
  description = "The name of the Azure Fleet"
  value       = azapi_resource.fleet.name
}

output "vm_list" {
  description = "List of virtual machines created with their name and public IP address."
  value = [
    for vm in var.virtual_machines : {
      name       = vm.name
      ip  = azurerm_public_ip.example[vm.name].ip_address
    }
  ]
}

output "vm_username" {
  value = var.vm_username
}

output "vm_ssh_key" {
  value = local_file.ssh_private_key.filename
}
