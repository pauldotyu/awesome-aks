resource "azapi_resource" "anyscale_cloud" {
  type      = "Anyscale.Platform/clouds@2026-02-01-preview"
  parent_id = azurerm_resource_group.example.id
  location  = azurerm_resource_group.example.location
  name      = local.random_name

  // this required when azapi local schema check isn't aware of the latest api version
  schema_validation_enabled = false

  body = {
    properties = {
      acrResourceId = azurerm_container_registry.example.id
    }
  }

  tags = {
    "anyscale-cloud" = local.random_name
  }
}

resource "azapi_resource" "anyscale_cloud_resource" {
  type      = "Anyscale.Platform/clouds/cloudResources@2026-02-01-preview"
  parent_id = azapi_resource.anyscale_cloud.id
  location  = azurerm_resource_group.example.location
  name      = "default"

  // this required when azapi local schema check isn't aware of the latest api version
  schema_validation_enabled = false

  body = {
    properties = {
      provider                    = "Azure"
      computeStack                = "K8S"
      cloudStorageBucketEndpoint  = azurerm_storage_account.example.primary_blob_endpoint
      cloudStorageBucketName      = "abfss://${azurerm_storage_container.example.name}@${azurerm_storage_account.example.primary_dfs_host}"
      anyscaleOperatorIamIdentity = azurerm_user_assigned_identity.example.principal_id
    }
  }

  tags = {
    "anyscale-cloud" = local.random_name
  }

  response_export_values = [
    "*"
  ]
}

resource "azurerm_kubernetes_cluster_extension" "anyscale_operator" {
  name           = "anyscaleoperator"
  cluster_id     = azurerm_kubernetes_cluster.example.id
  extension_type = "Anyscale.AKS.Operator"
  release_train  = "stable"

  plan {
    name      = "anyscale-operator"
    product   = "anyscale-operator-aks"
    publisher = "anyscale1750870039553"
  }

  configuration_settings = {
    "global.auth.audience"          = "api://086bc555-6989-4362-ba30-fded273e432b/.default"
    "global.auth.iamIdentity"       = azurerm_user_assigned_identity.example.client_id
    "global.cloudDeploymentId"      = azapi_resource.anyscale_cloud_resource.output.properties.cloudResourceId
    "global.controlPlaneURL"        = "https://console.azure.anyscale.com"
    "workloads.serviceAccount.name" = "anyscale-operator"
    "networking.gateway.enabled"    = "true"
    "networking.gateway.name"       = "gateway"
    "networking.gateway.className"  = "eg"
    "networking.gateway.namespace"  = "anyscale-operator"
    "networking.gateway.apiVersion" = "gateway.networking.k8s.io/v1"
    "networking.gateway.hostname"   = "${local.random_name}.${azurerm_kubernetes_cluster.example.location}.cloudapp.azure.com"
  }

  depends_on = [
    azurerm_federated_identity_credential.example,
    kubectl_manifest.envoy_proxy
  ]
}

resource "azurerm_role_assignment" "anyscale_platform_contributor" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Anyscale Platform Contributor Role"
  scope                = azapi_resource.anyscale_cloud.id
}
