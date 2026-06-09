resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  chart            = "oci://docker.io/envoyproxy/gateway-helm"
  version          = "v1.7.0"
  namespace        = "envoy-gateway-system"
  create_namespace = true
}

resource "kubectl_manifest" "envoy_proxy" {
  yaml_body = yamlencode({
    apiVersion = "gateway.envoyproxy.io/v1alpha1"
    kind       = "EnvoyProxy"
    metadata = {
      name      = "envoy-proxy"
      namespace = "envoy-gateway-system"
    }
    spec = {
      provider = {
        type = "Kubernetes"
        kubernetes = {
          envoyService = {
            type = "LoadBalancer"
            annotations = {
              "service.beta.kubernetes.io/azure-load-balancer-internal" = "false"
              "service.beta.kubernetes.io/azure-dns-label-name"         = local.random_name
            }
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.envoy_gateway
  ]
}

resource "kubectl_manifest" "gateway_class" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = "eg"
    }
    spec = {
      controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
      parametersRef = {
        group     = "gateway.envoyproxy.io"
        kind      = "EnvoyProxy"
        name      = "envoy-proxy"
        namespace = "envoy-gateway-system"
      }
    }
  })

  depends_on = [
    kubectl_manifest.envoy_proxy
  ]
}

resource "kubectl_manifest" "anyscale_gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "gateway"
      namespace = "anyscale-operator"
    }
    spec = {
      gatewayClassName = "eg"
      listeners = [
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
          allowedRoutes = {
            namespaces = {
              from = "Same"
            }
          }
        },
        {
          name     = "https"
          port     = 443
          protocol = "HTTPS"
          hostname = "*.i.azure.anyscaleuserdata.com"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                kind = "Secret"
                name = "anyscale-${replace(azapi_resource.anyscale_cloud_resource.output.properties.cloudResourceId, "_", "-")}-certificate"
              }
            ]
          }
          allowedRoutes = {
            namespaces = {
              from = "Same"
            }
          }
        },
        {
          name     = "https-session"
          port     = 443
          protocol = "HTTPS"
          hostname = "*.s.azure.anyscaleuserdata.com"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                kind = "Secret"
                name = "anyscale-${replace(azapi_resource.anyscale_cloud_resource.output.properties.cloudResourceId, "_", "-")}-certificate"
              }
            ]
          }
          allowedRoutes = {
            namespaces = {
              from = "Same"
            }
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.gateway_class,
    azurerm_kubernetes_cluster_extension.anyscale_operator
  ]
}