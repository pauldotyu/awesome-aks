resource "azurerm_key_vault" "example" {
  name                        = "akv${local.name}"
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name
  enabled_for_disk_encryption = true
  enable_rbac_authorization   = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
}

// Give yourself the ability to administer the Azure Key Vault instance
resource "azurerm_role_assignment" "akv_rbac_me" {
  scope                = azurerm_key_vault.example.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "example" {
  name         = "openai-api-key"
  value        = azurerm_cognitive_account.example.primary_access_key
  key_vault_id = azurerm_key_vault.example.id

  depends_on = [azurerm_role_assignment.akv_rbac_me]
}

resource "azurerm_app_configuration" "example" {
  name                = "aac${local.name}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "standard"

  identity {
    type = "SystemAssigned"
  }
}

// Give aac the ability to read secrets from the Key Vault instance
resource "azurerm_role_assignment" "akv_rbac_aac" {
  scope                = azurerm_key_vault.example.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_app_configuration.example.identity[0].principal_id
}

// Give yourself the ability to write key-value pairs to the App Configuration instance
resource "azurerm_role_assignment" "aac_rbac_me" {
  scope                = azurerm_app_configuration.example.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_app_configuration_key" "example_config_use_aoai" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "USE_AZURE_OPENAI"
  value                  = "True"

  depends_on = [
    azurerm_role_assignment.aac_rbac_me,
  ]
}

resource "azurerm_app_configuration_key" "example_config_use_aad" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "USE_AZURE_AD"
  value                  = "True"

  depends_on = [
    azurerm_role_assignment.aac_rbac_me
  ]
}

resource "azurerm_app_configuration_key" "example_config_model_name" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "AZURE_OPENAI_DEPLOYMENT_NAME"
  value                  = "gpt-35-turbo"

  depends_on = [
    azurerm_role_assignment.aac_rbac_me
  ]
}

resource "azurerm_app_configuration_key" "example_config_endpoint" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "AZURE_OPENAI_ENDPOINT"
  value                  = azurerm_cognitive_account.example.endpoint

  depends_on = [
    azurerm_role_assignment.aac_rbac_me
  ]
}

// Add a key-value pair that references a secret stored in Key Vault
resource "azurerm_app_configuration_key" "example_secrets_api_key" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "OPENAI_API_KEY"
  type                   = "vault"
  vault_key_reference    = azurerm_key_vault_secret.example.versionless_id

  depends_on = [
    azurerm_role_assignment.aac_rbac_me
  ]
}

resource "azurerm_user_assigned_identity" "aac" {
  location            = var.location
  name                = "aac-${local.name}"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_federated_identity_credential" "aac" {
  name                = "aac-${local.name}"
  resource_group_name = azurerm_resource_group.example.name
  parent_id           = azurerm_user_assigned_identity.aac.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject             = "system:serviceaccount:azappconfig-system:az-appconfig-k8s-provider"
}

// Give the VMSS identity the ability to read from the App Configuration instance
resource "azurerm_role_assignment" "aac_rbac_mi" {
  scope                = azurerm_app_configuration.example.id
  role_definition_name = "App Configuration Data Reader"
  principal_id         = azurerm_user_assigned_identity.aac.principal_id
}

// Give the VMSS identity the ability to read secrets from the Key Vault instance
resource "azurerm_role_assignment" "akv_rbac_mi" {
  scope                = azurerm_key_vault.example.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.aac.principal_id
}

// Deploy the App Configuration Kubernetes provider to the AKS cluster using Helm
// https://mcr.microsoft.com/en-us/product/azure-app-configuration/kubernetes-provider/tags
resource "helm_release" "appconfig_provider" {
  name             = "azureappconfiguration.kubernetesprovider"
  namespace        = "azappconfig-system"
  create_namespace = true
  chart            = "oci://mcr.microsoft.com/azure-app-configuration/helmchart/kubernetes-provider"
  version          = "1.0.0-preview4"
  cleanup_on_fail  = true

  depends_on = [
    azurerm_role_assignment.aac_rbac_mi,
    azurerm_role_assignment.akv_rbac_mi
  ]
}

// Sleep for 60 seconds to allow the App Configuration Kubernetes provider to deploy
resource "null_resource" "wait_for_helm" {
  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [
    helm_release.appconfig_provider
  ]
}

// Get the Kubernetes cluster configuration and save the file to the current directory on the local machine
resource "local_file" "example_aks_kubeconfig" {
  filename = "aks-kubeconfig"
  content  = azurerm_kubernetes_cluster.example.kube_config_raw
}

// Update the AzureAppConfigurationProvider CRD deployment to include the App Configuration endpoint and the VMSS identity client ID and save the file to the current directory on the local machine
resource "local_file" "example_appconfig_provider_manifest" {
  filename = "sample-appconfig-provider.yaml"
  content = templatefile("sample-appconfig-provider.tpl",
    {
      APP_CONFIG_ENDPOINT        = azurerm_app_configuration.example.endpoint,
      MANAGED_IDENTITY_CLIENT_ID = azurerm_user_assigned_identity.aac.client_id
    }
  )

  depends_on = [
    null_resource.wait_for_helm
  ]
}

// Using the kubeconfig file, apply the AzureAppConfigurationProvider CRD deployment to the AKS cluster
resource "null_resource" "example_appconfig_provider_apply" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${local_file.example_aks_kubeconfig.filename} apply -f ${local_file.example_appconfig_provider_manifest.filename}"
  }

  depends_on = [
    null_resource.wait_for_flux,
    null_resource.wait_for_helm
  ]

  triggers = {
    file_content = local_file.example_appconfig_provider_manifest.content
  }
}