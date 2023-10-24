variable "location" {
  description = "value of azure region"
  type        = string
  default     = "westeurope"
}

variable "ai_location" {
  description = "value of azure region for deploying azure open ai service"
  type        = string
  default     = "canadaeast"
}

variable "deploy_gpt4" {
  description = "value of boolean to deploy gpt4 model - if you have access to it"
  type        = bool
  default     = false
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
  default     = "london"
}

variable "k8s_namespace" {
  description = "value of kubernetes namespace"
  type        = string
  default     = "dev"
}