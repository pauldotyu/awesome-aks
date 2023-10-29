data "azurerm_resource_group" "mc" {
  name = azurerm_kubernetes_cluster.example.node_resource_group
}

resource "azurerm_user_assigned_identity" "alb" {
  location            = var.ai_location
  name                = "alb-${local.name}"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_federated_identity_credential" "alb" {
  name                = "alb-${local.name}"
  resource_group_name = azurerm_resource_group.example.name
  parent_id           = azurerm_user_assigned_identity.alb.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject             = "system:serviceaccount:azure-alb-system:alb-controller-sa"
}

resource "azurerm_role_assignment" "alb_mi_reader" {
  principal_id         = azurerm_user_assigned_identity.alb.principal_id
  role_definition_name = "Reader"
  scope                = data.azurerm_resource_group.mc.id
}

# Grant the ALB identity the "AppGw for Containers Configuration Manager" role on the AKS managed cluster resource group
resource "azurerm_role_assignment" "alb_mi_configuration_manager" {
  principal_id         = azurerm_user_assigned_identity.alb.principal_id
  role_definition_name = "AppGw for Containers Configuration Manager"
  scope                = data.azurerm_resource_group.mc.id

  depends_on = [null_resource.wait_for_aks]
}

# Grant the ALB identity the "Network Contributor" role to join devices to the subnet
resource "azurerm_role_assignment" "alb_mi_network_contributor" {
  principal_id         = azurerm_user_assigned_identity.alb.principal_id
  role_definition_name = "Network Contributor"
  scope                = azurerm_subnet.alb.id
}

resource "helm_release" "alb_controller" {
  name       = "alb-controller"
  repository = "oci://mcr.microsoft.com/application-lb/charts"
  chart      = "alb-controller"
  version    = "0.5.024542"
  wait       = false

  set {
    name  = "albController.podIdentity.clientID"
    value = azurerm_user_assigned_identity.alb.client_id
  }
}

// Sleep for 60 seconds to allow the App Configuration Kubernetes provider to deploy
resource "null_resource" "wait_for_alb_controller" {
  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [
    helm_release.alb_controller
  ]
}

// Update the ApplicationLoadBalancer CRD deployment to include the ALB subnet ID
resource "local_file" "applicationloadbalancer_manifest" {
  filename = "sample-applicationloadbalancer.yaml"
  content = templatefile("sample-applicationloadbalancer.tpl",
    {
      ALB_SUBNET_ID = azurerm_subnet.alb.id
    }
  )

  depends_on = [
    null_resource.wait_for_alb_controller
  ]
}

// Apply the ALB manifest
resource "null_resource" "applicationloadbalancer_apply" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${local_file.kubeconfig.filename} apply -f ${local_file.applicationloadbalancer_manifest.filename}"
  }

  triggers = {
    file_content = local_file.applicationloadbalancer_manifest.content
  }
}

// Update the Gateway CRD deployment to include the k8s namespace
resource "local_file" "gateway_manifest" {
  filename = "sample-gateway.yaml"
  content = templatefile("sample-gateway.tpl",
    {
      K8S_NAMESPACE = var.k8s_namespace
    }
  )

  depends_on = [
    null_resource.wait_for_alb_controller
  ]
}

// Apply the Gateway manifests
resource "null_resource" "gateway_apply" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${local_file.kubeconfig.filename} apply -f ${local_file.gateway_manifest.filename}"
  }

  triggers = {
    file_content = local_file.gateway_manifest.content
  }
}

// Sleep for 10 minutes to allow the Gateways to deploy
resource "null_resource" "wait_for_alb_gateways" {
  provisioner "local-exec" {
    command = "sleep 600"
  }

  depends_on = [
    null_resource.wait_for_demoapp,
    null_resource.gateway_apply,
  ]
}

data "external" "store_front_fqdn" {
  program = [
    "kubectl",
    "--kubeconfig",
    "${local_file.kubeconfig.filename}",
    "get",
    "gateway",
    "store-front-gateway",
    "-n",
    "${var.k8s_namespace}",
    "-o",
    "jsonpath={.status.addresses[0]}",
  ]

  depends_on = [
    null_resource.wait_for_alb_gateways
  ]
}

data "external" "store_admin_fqdn" {
  program = [
    "kubectl",
    "--kubeconfig",
    "${local_file.kubeconfig.filename}",
    "get",
    "gateway",
    "store-admin-gateway",
    "-n",
    "${var.k8s_namespace}",
    "-o",
    "jsonpath={.status.addresses[0]}",
  ]

  depends_on = [
    null_resource.wait_for_alb_gateways
  ]
}

// Update the Gateway CRD deployment to include the k8s namespace
resource "local_file" "httproute_manifest" {
  filename = "sample-httproute.yaml"
  content = templatefile("sample-httproute.tpl",
    {
      K8S_NAMESPACE    = var.k8s_namespace
      STORE_FRONT_FQDN = data.external.store_front_fqdn.result.value
      STORE_ADMIN_FQDN = data.external.store_admin_fqdn.result.value
    }
  )
}

// Apply the HTTRoute manifests
resource "null_resource" "httproute_apply" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${local_file.kubeconfig.filename} apply -f ${local_file.httproute_manifest.filename}"
  }

  triggers = {
    file_content = local_file.httproute_manifest.content
  }

  depends_on = [
    null_resource.wait_for_demoapp,
    null_resource.wait_for_alb_gateways,
    data.external.store_front_fqdn,
    data.external.store_admin_fqdn
  ]
}