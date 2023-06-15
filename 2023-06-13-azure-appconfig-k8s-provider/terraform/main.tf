terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.56.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "=2.4.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "=2.20.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "=2.9.0"
    }
  }
}

provider "azurerm" {
  features {
    app_configuration {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted         = true
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.example.kube_config.0.host
  username               = azurerm_kubernetes_cluster.example.kube_config.0.username
  password               = azurerm_kubernetes_cluster.example.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.example.kube_config.0.host
    username               = azurerm_kubernetes_cluster.example.kube_config.0.username
    password               = azurerm_kubernetes_cluster.example.kube_config.0.password
    client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
  }
}

data "azurerm_client_config" "current" {}

locals {
  name     = "appconfigdemo${random_integer.example.result}"
  location = "eastus"
}

resource "random_integer" "example" {
  min = 100
  max = 999
}

resource "random_password" "example" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.name}"
  location = local.location
}

resource "azurerm_kubernetes_cluster" "example" {
  name                = "aks${local.name}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "aks${local.name}"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault" "example" {
  name                        = "akv${local.name}"
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Backup",
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "Purge",
      "Recover",
      "Restore",
      "SetIssuers",
      "Update"
    ]

    key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey",
      "Release",
      "Rotate",
      "GetRotationPolicy",
      "SetRotationPolicy"
    ]

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set"
    ]

    storage_permissions = [
      "Backup",
      "Delete",
      "DeleteSAS",
      "Get",
      "GetSAS",
      "List",
      "ListSAS",
      "Purge",
      "Recover",
      "RegenerateKey",
      "Restore",
      "Set",
      "SetSAS",
      "Update"
    ]
  }
}

resource "azurerm_key_vault_secret" "example" {
  name         = "password"
  value        = random_password.example.result
  key_vault_id = azurerm_key_vault.example.id
}

resource "azurerm_app_configuration" "example" {
  name                = "aac${local.name}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "standard"
}

// Give yourself the ability to write key-value pairs to the App Configuration instance
resource "azurerm_role_assignment" "example" {
  scope                = azurerm_app_configuration.example.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

// Give aks the ability to read key-value pairs to the App Configuration instance
resource "azurerm_role_assignment" "example_aks" {
  scope                = azurerm_app_configuration.example.id
  role_definition_name = "App Configuration Data Reader"
  principal_id         = azurerm_kubernetes_cluster.example.identity[0].principal_id
}

// Give kubelet the ability to read key-value pairs to the App Configuration instance
resource "azurerm_role_assignment" "example_kubelet" {
  scope                = azurerm_app_configuration.example.id
  role_definition_name = "App Configuration Data Reader"
  principal_id         = azurerm_kubernetes_cluster.example.kubelet_identity[0].object_id
}

resource "azurerm_app_configuration_key" "example_settings_greeting" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "settings.greeting"
  value                  = "Hello"

  depends_on = [
    azurerm_role_assignment.example
  ]
}

resource "azurerm_app_configuration_key" "example_settings_name" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "settings.name"
  value                  = "Paul"

  depends_on = [
    azurerm_role_assignment.example
  ]
}

// Add a key-value pair that references a secret stored in Key Vault
resource "azurerm_app_configuration_key" "example_secrets_password" {
  configuration_store_id = azurerm_app_configuration.example.id
  key                    = "secrets.password"
  type                   = "vault"
  vault_key_reference    = azurerm_key_vault_secret.example.versionless_id

  depends_on = [
    azurerm_role_assignment.example
  ]
}

// Get the name of VMSS that is created by AKS
// The external data source is used because the VMSS is created by AKS and Terraform does not have state information about it
data "external" "aks_node_vmss" {
  program = [
    "az",
    "resource",
    "list",
    "--resource-group",
    "${azurerm_kubernetes_cluster.example.node_resource_group}",
    "--resource-type",
    "Microsoft.Compute/virtualMachineScaleSets",
    "--query",
    "[0].{name:name}"
  ]
}

// Create a managed identity and assign the App Configuration Data Reader role to the VMSS
// The local-exec provisioner is used because the VMSS is managed by AKS
resource "null_resource" "rbac_appconfig_aks" {
  provisioner "local-exec" {
    command = "az vmss identity assign --role \"App Configuration Data Reader\"  --scope ${azurerm_app_configuration.example.id} --name ${data.external.aks_node_vmss.result.name} --resource-group ${azurerm_kubernetes_cluster.example.node_resource_group}"
  }

  depends_on = [
    azurerm_app_configuration.example,
    data.external.aks_node_vmss,
    azurerm_kubernetes_cluster.example
  ]
}

// sleep for 90 seconds to allow the managed identity to be created
resource "null_resource" "sleep" {
  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [
    null_resource.rbac_appconfig_aks
  ]
}

// Get the object ID of the VMSS identity
// The external data source is used because the VMSS is created by AKS and Terraform does not have state information about it
data "external" "aks_node_vmss_identity_object_id" {
  program = [
    "az",
    "vmss",
    "identity",
    "show",
    "--name",
    "${data.external.aks_node_vmss.result.name}",
    "--resource-group",
    "${azurerm_kubernetes_cluster.example.node_resource_group}",
    "--query", "{principal_id: principalId}"
  ]

  depends_on = [
    null_resource.sleep
  ]
}

// Get the client ID of the VMSS identity
// The external data source is used because the VMSS is created by AKS and Terraform does not have state information about it
data "external" "aks_node_vmss_identity_client_id" {
  program = [
    "az",
    "ad",
    "sp",
    "show",
    "--id",
    "${data.external.aks_node_vmss_identity_object_id.result.principal_id}",
    "--query",
    "{app_id: appId}"
  ]


  depends_on = [
    data.external.aks_node_vmss_identity_object_id
  ]

}

// Give the VMSS identity the ability to read key-value pairs from the App Configuration instance
resource "azurerm_key_vault_access_policy" "example" {
  key_vault_id = azurerm_key_vault.example.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.external.aks_node_vmss_identity_object_id.result.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

// Give the aks identity the ability to read key-value pairs from the App Configuration instance
resource "azurerm_key_vault_access_policy" "example_aks" {
  key_vault_id = azurerm_key_vault.example.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.example.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

// Give the kubelet identity the ability to read key-value pairs from the App Configuration instance
resource "azurerm_key_vault_access_policy" "example_kubelet" {
  key_vault_id = azurerm_key_vault.example.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.example.kubelet_identity[0].object_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

// Deploy the App Configuration Kubernetes provider to the AKS cluster using Helm
resource "helm_release" "appconfig_provider" {
  name             = "azureappconfiguration.kubernetesprovider"
  namespace        = "azappconfig-system"
  create_namespace = true
  chart            = "oci://mcr.microsoft.com/azure-app-configuration/helmchart/kubernetes-provider"
  version          = "1.0.0-preview"
  cleanup_on_fail  = true

  depends_on = [
    null_resource.rbac_appconfig_aks
  ]
}

// Sleep for 60 seconds to allow the App Configuration Kubernetes provider to deploy
resource "null_resource" "sleep_again" {
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
      APP_CONFIG_ENDPOINT         = azurerm_app_configuration.example.endpoint,
      NODE_VMSS_MANAGED_CLIENT_ID = data.external.aks_node_vmss_identity_client_id.result.app_id
    }
  )

  depends_on = [
    null_resource.sleep_again
  ]
}

// Using the kubeconfig file, apply the AzureAppConfigurationProvider CRD deployment to the AKS cluster
resource "null_resource" "example_appconfig_provider_apply" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${local_file.example_aks_kubeconfig.filename} apply -f ${local_file.example_appconfig_provider_manifest.filename}"
  }

  depends_on = [
    null_resource.example_appconfig_provider_apply
  ]
}

// sleep for 60 seconds to allow the AzureAppConfigurationProvider CRD deployment to deploy
resource "null_resource" "sleep_one_last_time" {
  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [
    null_resource.example_appconfig_provider_apply
  ]
}


// Retrieve the configmap created by the AzureAppConfigurationProvider CRD deployment
data "kubernetes_config_map" "example" {
  metadata {
    name = "my-configmap"
  }

  depends_on = [
    null_resource.example_appconfig_provider_apply,
    null_resource.sleep_one_last_time
  ]
}

// Retrieve the secret created by the AzureAppConfigurationProvider CRD deployment
data "kubernetes_secret" "example" {
  metadata {
    name = "my-secrets"
  }


  depends_on = [
    null_resource.example_appconfig_provider_apply,
    null_resource.sleep_one_last_time
  ]
}

resource "kubernetes_pod" "example" {
  metadata {
    name = "my-app"
  }

  spec {
    container {
      image = "busybox"
      name  = "mybusybox"

      args = ["sleep", "3600"]

      env_from {
        config_map_ref {
          name = data.kubernetes_config_map.example.metadata[0].name
        }
      }

      env {
        name = "secrets.password"
        value_from {
          secret_key_ref {
            name = data.kubernetes_secret.example.metadata[0].name
            key  = "secrets.password"
          }
        }
      }
    }
  }

  depends_on = [
    data.kubernetes_config_map.example,
    data.kubernetes_secret.example
  ]
}

// Using the kubeconfig file, apply the AzureAppConfigurationProvider CRD deployment to the AKS cluster
resource "null_resource" "example_appconfig_provider_test" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${local_file.example_aks_kubeconfig.filename} exec my-app -- env"
  }

  depends_on = [
    kubernetes_pod.example
  ]
}

// Outputs
output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.example.name
}

output "aks_node_vmss" {
  value = data.external.aks_node_vmss.result
}

output "aks_node_vmss_identity_object_id" {
  value = data.external.aks_node_vmss_identity_object_id.result
}

output "aks_node_vmss_identity_client_id" {
  value = data.external.aks_node_vmss_identity_client_id.result
}

output "aks_identity" {
  value = azurerm_kubernetes_cluster.example.identity[0].principal_id
}

output "aks_kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.example.kubelet_identity[0].object_id
}

output "aks_kubelet_identity_client_id" {
  value = azurerm_kubernetes_cluster.example.kubelet_identity[0].client_id
}

output "configmap" {
  value = data.kubernetes_config_map.example
}

output "secret" {
  value     = data.kubernetes_secret.example
  sensitive = true
}
