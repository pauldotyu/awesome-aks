variable "location" {
  description = "value of azure region"
  type        = string
  default     = "southcentralus"
}

variable "gh_user" {
  description = "value of github organization or account where the repo is hosted"
  type        = string
}

variable "gh_token" {
  description = "value of github personal access token"
  type        = string
  sensitive   = true
}

variable "repo_name" {
  description = "value of github repo name"
  type        = string
  default     = "aks-store-demo-manifests"
}

variable "repo_branch" {
  description = "value of github repo branch"
  type        = string
  default     = "flux-k8s-ext"
}

variable "k8s_namespace" {
  description = "value of kubernetes namespace"
  type        = string
  default     = "dev"
}