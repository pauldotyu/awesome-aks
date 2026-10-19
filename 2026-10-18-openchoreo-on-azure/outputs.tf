output "rg_name" {
  description = "The name of the resource group."
  value       = azurerm_resource_group.example.name
}

output "aks_name" {
  description = "The name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.example.name
}

output "aks_nginx_free_lb_note" {
  description = "How to obtain kubeconfig / get credentials for the cluster."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.example.name} --name ${azurerm_kubernetes_cluster.example.name} --admin ; or: KUBECONFIG=${local.kubeconfig_filename} kubectl ... (written by terraform)."
}

output "tenant_id" {
  description = "The Entra tenant id (used to build the OIDC v2 endpoints)."
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "The Azure subscription hosting the environment (AKS, Key Vault, identities). The Azure DNS zone lives in a different subscription — see dns_zone_subscription_id."
  value       = local.environment_subscription_id
}

# --- OpenChoreo / Entra identity -----------------------------------------

output "openchoreo_api_client_id" {
  description = "The openchoreo-api application (client) id. This is the JWT audience (security.jwt.audience)."
  value       = azuread_application.openchoreo_api.client_id
}

output "openchoreo_api_app_id_uri" {
  description = "The openchoreo-api application identifier uri (api://<client-id>)."
  value       = local.openchoreo_api_app_id_uri
}

output "openchoreo_backstage_client_id" {
  description = "The openchoreo-backstage (browser sign-in) application id."
  value       = azuread_application.openchoreo_backstage.client_id
}

output "openchoreo_backstage_service_client_id" {
  description = "The openchoreo-backstage-service application id. This is matched by the service_account entitlement `azp` claim for the catalog-reader binding."
  value       = azuread_application.openchoreo_backstage_service.client_id
}

output "platform_engineer_group_object_id" {
  description = "The object id of the configured platform-engineer Entra group. Users in this group are authorized for the control plane via the `groups` claim."
  value       = data.azuread_group.platform_engineer.object_id
}

# --- Certificates --------------------------------------------------------

output "selected_issuer" {
  description = "The ClusterIssuer backing cp-gateway-tls (letsencrypt-azure-dns-staging by default)."
  value       = local.selected_issuer
}

output "letsencrypt_environment" {
  description = "The Let's Encrypt environment currently backing cp-gateway-tls. Switch to \"production\" and re-apply to move off staging."
  value       = var.letsencrypt_environment
}

# --- DNS -----------------------------------------------------------------

output "dns_zone_name" {
  description = "The Azure DNS zone name."
  value       = var.dns_zone_name
}

output "dns_zone_nameservers" {
  description = "The Azure DNS zone nameservers. These are normally already delegated at the registrar; use this to confirm."
  value       = local.dns_zone_name_servers
}

output "dns_zone_resource_group_name" {
  description = "The resource group holding the Azure DNS zone."
  value       = local.dns_zone_resource_group_name
}

output "dns_zone_subscription_id" {
  description = "The subscription holding the Azure DNS zone. May differ from the cluster subscription."
  value       = local.dns_zone_subscription_id
}

output "cert_manager_dns_role_managed_by_terraform" {
  description = "Whether Terraform created the DNS Zone Contributor role assignment in the DNS zone's subscription."
  value       = var.manage_cert_manager_dns_role
}

output "dns_a_records_managed_by_terraform" {
  description = "Whether Terraform created the console/api A records in the DNS zone's subscription."
  value       = var.manage_dns_a_records
}

output "dns_zone_managed_by_terraform" {
  description = "Whether Terraform created the DNS zone. When false the zone pre-existed and the registrar nameservers are assumed to be delegated already."
  value       = local.dns_zone_managed
}

output "console_url" {
  description = "The public OpenChoreo console URL."
  value       = "https://${var.console_hostname}"
}

output "api_url" {
  description = "The public OpenChoreo API URL."
  value       = "https://${var.api_hostname}"
}

# --- Secret store (Azure-native replacement for OpenBao) ----------------

output "key_vault_uri" {
  description = "The Azure Key Vault URI backing External Secrets Operator."
  value       = azurerm_key_vault.example.vault_uri
}

# --- Local files ---------------------------------------------------------

output "kubeconfig_filename" {
  description = "Path to the AKS kubeconfig written to the working directory."
  value       = "${path.cwd}/${local.kubeconfig_filename}"
}

output "control_plane_values_filename" {
  description = "Path to the generated OpenChoreo control-plane values file (contains no secret values)."
  value       = "${path.cwd}/control-plane-values.yaml"
}
