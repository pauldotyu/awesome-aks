resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = "1.28.3"
  namespace        = "istio-system"
  create_namespace = true
}

resource "helm_release" "istiod" {
  name             = "istiod"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "istiod"
  version          = "1.28.3"
  namespace        = "istio-system"
  create_namespace = false

  set = [
    {
      name  = "pilot.env.ENABLE_GATEWAY_API_INFERENCE_EXTENSION"
      value = "true"
    },
  ]

  depends_on = [helm_release.istio_base]
}
