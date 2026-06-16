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

  response_export_values = [
    "properties.ssoUrl",
    "properties.cloudResourceId"
  ]

  depends_on = [
    azapi_resource.aks
  ]
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
    "properties.cloudResourceId"
  ]

  depends_on = [
    azapi_resource.aks
  ]
}

locals {
  ANYSCALE_CLOUD_RESOURCE_ID = replace(azapi_resource.anyscale_cloud_resource.output.properties.cloudResourceId, "_", "-")
}

resource "azurerm_kubernetes_cluster_extension" "anyscale_operator" {
  name           = "anyscaleoperator"
  cluster_id     = azapi_resource.aks.id
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
    "networking.gateway.className"  = "approuting-istio"
    "networking.gateway.namespace"  = "anyscale-operator"
    "networking.gateway.apiVersion" = "gateway.networking.k8s.io/v1"
    "networking.gateway.hostname"   = "${local.ANYSCALE_CLOUD_RESOURCE_ID}.${azapi_resource.aks.location}.cloudapp.azure.com"
  }

  depends_on = [
    azurerm_federated_identity_credential.example
  ]
}

resource "azurerm_role_assignment" "anyscale_platform_contributor" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Anyscale Platform Contributor Role"
  scope                = azapi_resource.anyscale_cloud.id
}

resource "kubectl_manifest" "anyscale_gateway" {
  yaml_body = <<-EOT
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: gateway
      namespace: anyscale-operator
    spec:
      gatewayClassName: approuting-istio
      infrastructure:
        annotations:
          service.beta.kubernetes.io/azure-dns-label-name: ${local.ANYSCALE_CLOUD_RESOURCE_ID}
      listeners:
        - name: http
          port: 80
          protocol: HTTP
          allowedRoutes:
            namespaces:
              from: Same
        - name: https
          port: 443
          protocol: HTTPS
          hostname: "*.i.azure.anyscaleuserdata.com"
          tls:
            mode: Terminate
            certificateRefs:
              - kind: Secret
                name: anyscale-${local.ANYSCALE_CLOUD_RESOURCE_ID}-certificate
          allowedRoutes:
            namespaces:
              from: Same
        - name: https-session
          port: 443
          protocol: HTTPS
          hostname: "*.s.azure.anyscaleuserdata.com"
          tls:
            mode: Terminate
            certificateRefs:
              - kind: Secret
                name: anyscale-${local.ANYSCALE_CLOUD_RESOURCE_ID}-certificate
          allowedRoutes:
            namespaces:
              from: Same
  EOT

  depends_on = [
    azurerm_kubernetes_cluster_extension.anyscale_operator
  ]
}

resource "kubectl_manifest" "nvidia_node_pool" {
  yaml_body = <<-EOT
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      annotations:
        kubernetes.io/description: Specialized NodePool for workloads requiring GPUs.
      name: nvidia
    spec:
      disruption:
        budgets:
        - nodes: 30%
        consolidateAfter: 15m
        consolidationPolicy: WhenEmpty
      template:
        metadata:
          labels:
            kubernetes.azure.com/ebpf-dataplane: cilium
        spec:
          expireAfter: Never
          nodeClassRef:
            group: karpenter.azure.com
            kind: AKSNodeClass
            name: default
          requirements:
          - key: kubernetes.io/arch
            operator: In
            values:
            - amd64
          - key: kubernetes.io/os
            operator: In
            values:
            - linux
          - key: karpenter.sh/capacity-type
            operator: In
            values:
            - on-demand
          - key: karpenter.azure.com/sku-name
            operator: In
            values:
            - ${var.nvidia_sku_name}
          startupTaints:
          - effect: NoExecute
            key: node.cilium.io/agent-not-ready
            value: "true"
          taints:
          - effect: NoSchedule
            key: nvidia.com/gpu
            value: "present"
  EOT
}