variable "location" {
  description = "value of azure region"
  type        = string
  default     = "westeurope"
}

variable "vm_size" {
  description = "value of azure vm size"
  type        = string
  default     = "Standard_D4s_v4"
}

variable "node_count" {
  description = "value of azure vm node count"
  type        = number
  default     = 3
}

variable "os_sku" {
  description = "value of azure vm os sku"
  type        = string
  default     = "Ubuntu"
}

variable "ai_location" {
  description = "value of azure region for deploying azure open ai service"
  type        = string
  default     = "westeurope"
}

variable "ai_model_version" {
  description = "value of azure open ai service model version"
  type        = string
  default     = "0301"
}

variable "ai_model_capacity" {
  description = "value of azure open ai service model capacity"
  type        = number
  default     = 120
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
  default     = "kubecon"
}

variable "k8s_namespace" {
  description = "value of kubernetes namespace"
  type        = string
  default     = "dev"
}