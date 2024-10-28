resource "helm_release" "argo_cd" {
  name             = "argocd-release"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.6.10"
  namespace        = "argocd"
  create_namespace = true
}

resource "helm_release" "argo_events" {
  name             = "argoevents-release"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-events"
  version          = "2.4.8"
  namespace        = "argo-events"
  create_namespace = true
}

resource "helm_release" "argo_workflows" {
  name             = "argoworkflows-release"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-workflows"
  version          = "0.42.5"
  namespace        = "argo"
  create_namespace = true
}
