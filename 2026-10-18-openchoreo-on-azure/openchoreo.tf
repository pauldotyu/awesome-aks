# ---------------------------------------------------------------------------
# OpenChoreo control plane
#
# Install order (all explicitly chained via depends_on):
#   1. openchoreo-control-plane namespace
#   2. Gateway API CRDs v1.5.1 (cluster-wide, imperative)
#   3. kgateway CRDs + kgateway 2.3.1 (in openchoreo-control-plane)
#   4. Let's Encrypt ClusterIssuers (cert-manager.tf) + cp-gateway-tls
#   5. ESO ClusterSecretStore + backstage-secrets ExternalSecret
#   6. control-plane install, gated on cp-gateway-tls Ready and backstage-secrets
#   7. Azure DNS A records for console/api once the LoadBalancer IP is known
#
# No ThunderID, OpenBao, or sample workloads are installed.
#
# NOTE: cluster objects are applied with kubectl rather than the Kubernetes
# Terraform provider, because the provider needs a live cluster connection at
# plan time and the AKS cluster is created by this same apply.
# ---------------------------------------------------------------------------

resource "terraform_data" "openchoreo_namespace" {
  input = {
    namespace = local.openchoreo_namespace
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/files/create-namespace.sh"
    environment = {
      KUBECONFIG_FILE = local_file.kubeconfig.filename
      OCP_NAMESPACE   = local.openchoreo_namespace
    }
  }

  depends_on = [
    local_file.kubeconfig,
  ]
}

# 1/2 Gateway API CRDs (cluster-scoped, applied by kubectl).
resource "terraform_data" "apply_gateway_api_crd" {
  input = {
    version = var.gateway_api_version
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/files/apply-gateway-api-crd.sh"
    environment = {
      KUBECONFIG_FILE     = local_file.kubeconfig.filename
      GATEWAY_API_VERSION = var.gateway_api_version
    }
  }

  depends_on = [
    local_file.kubeconfig,
  ]
}

# 3/2 kgateway CRDs then kgateway. The CRD install is idempotent.
resource "helm_release" "kgateway_crds" {
  name             = "kgateway-crds"
  chart            = "oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds"
  version          = var.kgateway_version
  namespace        = local.openchoreo_namespace
  create_namespace = false

  depends_on = [
    terraform_data.openchoreo_namespace,
    terraform_data.apply_gateway_api_crd,
  ]
}

resource "helm_release" "kgateway" {
  name             = "kgateway"
  chart            = "oci://cr.kgateway.dev/kgateway-dev/charts/kgateway"
  version          = var.kgateway_version
  namespace        = local.openchoreo_namespace
  create_namespace = false

  depends_on = [
    helm_release.kgateway_crds,
    terraform_data.apply_gateway_api_crd,
    terraform_data.openchoreo_namespace,
  ]
}

# 4/2 The control-plane serving certificate. DNS names cover the control plane
# now and pre-provision the data plane (*.apps) and observability (observer.obs)
# on the same zone so the same issuer path can be reused later.
resource "local_file" "cp_gateway_tls" {
  filename = "cp-gateway-tls.yaml"
  content = templatefile("${path.module}/files/cp-gateway-tls.yaml.tpl", {
    namespace = local.openchoreo_namespace
    issuer    = local.selected_issuer
    dns_names = local.cp_tls_dns_names
  })
}

resource "terraform_data" "cp_gateway_tls" {
  input = {
    manifest = local_file.cp_gateway_tls.content
    issuer   = local.selected_issuer
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/files/kubectl-apply.sh"
    environment = {
      KUBECONFIG_FILE = local_file.kubeconfig.filename
      MANIFEST_FILE   = local_file.cp_gateway_tls.filename
      WAIT_KIND       = "certificate"
      WAIT_NAME       = "cp-gateway-tls"
      WAIT_NAMESPACE  = local.openchoreo_namespace
      WAIT_CONDITION  = "Ready"
      WAIT_TIMEOUT    = "600s"
    }
  }

  depends_on = [
    terraform_data.openchoreo_namespace,
    terraform_data.letsencrypt_issuers,
    # The DNS-01 challenge cannot succeed until cert-manager holds DNS Zone
    # Contributor on the zone. Azure RBAC takes a short while to propagate, and
    # cert-manager retries the challenge until it succeeds.
    azurerm_role_assignment.cert_manager_dns,
    local_file.kubeconfig,
  ]
}

# 4/1 Render the generated control-plane values from the template + locals.
# The file contains only non-secret identifiers (client ids, tenant id, group
# object id). The real secrets live in Azure Key Vault and are projected into
# the cluster by ESO, so nothing sensitive is written to disk here.
resource "local_file" "control_plane_values" {
  filename        = "control-plane-values.yaml"
  content         = templatefile("${path.module}/files/control-plane-values.yaml.tpl", local.openchoreo_values)
  file_permission = "0400"
}

# 6 The gated install. Waits (in-cluster) for cp-gateway-tls Ready and the
# ESO-materialized backstage-secrets before installing the control plane.
resource "terraform_data" "install_openchoreo_control_plane" {
  input = {
    values = local_file.control_plane_values.content
    issuer = local.selected_issuer
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/files/install-openchoreo.sh"
    environment = {
      KUBECONFIG_FILE    = local_file.kubeconfig.filename
      OCP_NAMESPACE      = local.openchoreo_namespace
      OCP_VALUES_FILE    = local_file.control_plane_values.filename
      OPENCHOREO_VERSION = var.openchoreo_control_plane_version
    }
  }

  depends_on = [
    terraform_data.apply_gateway_api_crd,
    helm_release.kgateway_crds,
    helm_release.kgateway,
    terraform_data.cp_gateway_tls,
    terraform_data.backstage_secrets,
    local_file.control_plane_values,
  ]
}

# 7 Azure DNS A records for console/api once the LoadBalancer IP is known.
resource "terraform_data" "create_dns_a_records" {
  count = var.manage_dns_a_records ? 1 : 0

  input = {
    zone         = var.dns_zone_name
    rg           = local.dns_zone_resource_group_name
    subscription = local.dns_zone_subscription_id
    ns           = local.openchoreo_namespace
    version      = var.openchoreo_control_plane_version
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/files/create-dns-records.sh"
    environment = {
      KUBECONFIG_FILE     = local_file.kubeconfig.filename
      OCP_NAMESPACE       = local.openchoreo_namespace
      DNS_ZONE            = var.dns_zone_name
      RESOURCE_GROUP      = local.dns_zone_resource_group_name
      DNS_SUBSCRIPTION_ID = local.dns_zone_subscription_id
    }
  }

  depends_on = [
    terraform_data.install_openchoreo_control_plane,
  ]
}
