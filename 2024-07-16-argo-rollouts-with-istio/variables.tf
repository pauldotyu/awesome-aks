variable "location" {
  description = "value of azure region"
  type        = string
  default     = "westus3"
}

variable "ai_location" {
  description = "value of azure region for deploying azure open ai service"
  type        = string
  default     = "eastus"
}

variable "deploy_gpt4" {
  description = "value of boolean to deploy gpt4 model - if you have access to it"
  type        = bool
  default     = true
}

variable "gpt4_deployment_name" {
  description = "value of azure open ai gpt4 deployment name"
  type        = string
  default     = "gpt-4o"
}

variable "deploy_dalle" {
  description = "value of boolean to deploy dall-e model - if you have access to it"
  type        = bool
  default     = true
}

variable "dalle_deployment_name" {
  description = "value of azure open ai dall-e deployment name"
  type        = string
  default     = "dall-e-3"
}

variable "k8s_version" {
  description = "value of kubernetes version"
  type        = string
  default     = "1.30.0"
}

variable "k8s_namespace" {
  description = "value of kubernetes namespace"
  type        = string
  default     = "pets"
}